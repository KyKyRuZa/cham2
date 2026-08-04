import time
import gc
import secrets
import numpy as np
import torch
from io import BytesIO
from dataclasses import dataclass
from PIL import Image, ImageOps

from server.state import _predictor, _pipe, _device, _request_counter
from server.config import MAX_IMAGE_SIZE_BYTES, MAX_IMAGE_DIMENSION
from server.prompts import get_color_hex_name, mask_iou, MATERIAL_PROMPTS, DEFAULT_PROMPT, sanitize_prompt_text
import logging

logger = logging.getLogger(__name__)


@dataclass
class RecolorTask:
    img_bytes: bytes
    point_x: float
    point_y: float
    material: str
    color_hex: str
    color_name: str
    object_name: str
    strength: float
    guidance_scale: float
    num_inference_steps: int
    patina: bool
    color_r: int | None = None
    color_g: int | None = None
    color_b: int | None = None
    from_pipette: bool = False


def run_recolor_job(task: RecolorTask) -> bytes:
    """Синхронная тяжёлая обработка одного запроса (декод, SAM-2, FLUX, кодирование PNG).

    Вызывается через ``asyncio.to_thread`` из эндпоинта ``ai_recolor``.
    """
    img_bytes = task.img_bytes
    point_x = task.point_x
    point_y = task.point_y
    material = task.material
    color_hex = task.color_hex
    color_name = task.color_name
    object_name = task.object_name
    strength = task.strength
    guidance_scale = task.guidance_scale
    num_inference_steps = task.num_inference_steps
    patina = task.patina
    color_r = task.color_r
    color_g = task.color_g
    color_b = task.color_b
    from_pipette = task.from_pipette
    start_time = time.time()

    # 1. Декодирование изображения
    try:
        source_image = Image.open(BytesIO(img_bytes))
        source_image = ImageOps.exif_transpose(source_image)
        source_image = source_image.convert("RGB")
    except Exception as e:
        logger.error(f"❌ PIL decode error: {e}")
        raise HTTPException(400, f"Invalid image: {e}")
    w, h = source_image.size
    logger.info(f"   Image dimensions: {w}x{h} (EXIF orientation applied server-side)")

    # Ресайз до разумного размера (макс. 1024x1024) для стабильности
    max_size = 1024
    if w > max_size or h > max_size:
        source_image.thumbnail((max_size, max_size))
        new_w, new_h = source_image.size
        logger.info(f"   Resized to: {new_w}x{new_h}")
    else:
        logger.info("   No resize needed")

    source_image_np = np.array(source_image)
    logger.info(f"   Image array shape: {source_image_np.shape}")
    image_height, image_width = source_image_np.shape[:2]
    image_area = image_width * image_height

    scale_x = source_image.width / w
    scale_y = source_image.height / h

    logger.info(f"   Resize scale: scale_x={scale_x:.4f}, scale_y={scale_y:.4f}")

    scaled_point_x = int(point_x * scale_x)
    scaled_point_y = int(point_y * scale_y)
    logger.info(f"   Scaled prompt point: ({point_x}, {point_y}) -> ({scaled_point_x}, {scaled_point_y})")
    point_x = scaled_point_x
    point_y = scaled_point_y

    # 2. Преобразование color_hex
    if color_hex.startswith("0x") or color_hex.startswith("0X"):
        color_hex_int = int(color_hex, 16)
    else:
        try:
            color_hex_int = int(color_hex)
        except ValueError:
            raise HTTPException(400, f"Invalid color_hex format: '{color_hex}'")
    if not (0 <= color_hex_int <= 0xFFFFFF):
        raise HTTPException(400, f"color_hex out of RGB range: '{color_hex}'")
    logger.info(f"   Parsed color_hex_int: {color_hex_int}")

    # Проверяем, что source_image всё ещё валидна после всех операций
    logger.info(f"   source_image type before generation: {type(source_image)}, size: {source_image.size if source_image else 'N/A'}")

    # 3. Сегментация SAM-2 с consistency-check (2 прогона с джиттер-точками)
    seg_start = time.time()

    # Генерируем 2 джиттер-точки вокруг исходной точки клика
    jitter_offsets = [(8, 0), (0, -8)]
    jitter_points = []
    for dx, dy in jitter_offsets:
        jx = max(0, min(image_width - 1, point_x + dx))
        jy = max(0, min(image_height - 1, point_y + dy))
        jitter_points.append((jx, jy))

    # Выполняем сегментацию для каждой точки
    all_mask_candidates = []
    all_scores = []
    all_coords = [(point_x, point_y)] + jitter_points

    with torch.no_grad():
        if hasattr(_predictor, 'reset_state'):
            _predictor.reset_state()
        _predictor.set_image(source_image_np)

        for cx, cy in all_coords:
            masks, scores, logits = _predictor.predict(
                point_coords=np.array([[cx, cy]]),
                point_labels=np.array([1]),
                multimask_output=True,
            )
            best_idx_local = np.argmax(scores)
            all_mask_candidates.append(masks[best_idx_local])
            all_scores.append(scores[best_idx_local])
            logger.info(f"   SAM-2: point=({cx}, {cy}), best mask score={scores[best_idx_local]:.3f}")

    # Находим финальную маску по максимальному среднему IoU
    best_mask_idx = 0
    best_mean_iou = 0.0
    for i, mask_i in enumerate(all_mask_candidates):
        ious = [mask_iou(mask_i, all_mask_candidates[j]) for j in range(len(all_mask_candidates)) if j != i]
        mean_iou = sum(ious) / len(ious) if ious else 0.0
        if mean_iou > best_mean_iou:
            best_mean_iou = mean_iou
            best_mask_idx = i

    best_mask = all_mask_candidates[best_mask_idx]
    mask_area = np.sum(best_mask)
    mask_area_percent = mask_area / (image_width * image_height) * 100

    logger.info(f"   SAM-2: final mask from point {all_coords[best_mask_idx]}, score={all_scores[best_mask_idx]:.3f}")
    logger.info(f"   SAM-2: mask area={mask_area} pixels ({mask_area_percent:.2f}% of image), mean IoU={best_mean_iou:.3f}")

    # Проверка стабильности сегментации
    if best_mean_iou < 0.5:
        logger.warning(f"⚠️  Low mask consistency (mean IoU={best_mean_iou:.3f} < 0.5) — point may be near object boundary")

    if mask_area < 10:
        logger.warning("⚠️  Mask area is very small – object might not be detected!")

    seg_time = time.time() - seg_start
    logger.info(f"   Segmentation took {seg_time:.2f}s (2 runs with consistency-check)")

    # 4. Формирование промпта с цветом (именованное название) и названием объекта
    # Используем переданное имя цвета если оно есть
    if color_name and color_name != "":
        color_name = color_name
    else:
        color_name = get_color_hex_name(color_hex_int)
    hex_color_str = f"#{color_hex_int:06x}"

    # Точное описание цвета (hex + RGB), чтобы модель получала больше данных
    # о реальном оттенке, особенно когда цвет пришёл из пипетки.
    if None not in (color_r, color_g, color_b):
        exact_color_desc = f"{hex_color_str} (RGB {color_r}, {color_g}, {color_b})"
    else:
        exact_color_desc = hex_color_str

    # Яркие цвета не нужно усиливать словом "bright"
    bright_colors = {"light blue", "light coral", "light pink", "white", "off white", "yellow", "aqua", "cyan", "light gray"}

    # Специальные имена металлов
    exact_metal_names = {"gold", "silver", "bronze", "stainless_steel", "brass", "copper", "titanium"}

    # Flat-matte только когда материал реально «без текстуры».
    # Для остальных материалов всегда используем шаблон материала
    # (с блеском у металлов и текстурой у дерева/кожи/ткани и т.п.),
    # независимо от того, выбран ли вариант текстуры.
    if material == "no_texture":
        # Без текстуры - только цвет (для всех материалов)
        prompt = f"The {object_name} is recolored to {exact_color_desc}, same shape, flat {color_name} color, hex {hex_color_str}, no texture, smooth matte surface, photorealistic"
    elif material == "metal":
        # Металл: блеск и отражения. Конкретный металл берётся по имени цвета,
        # иначе — универсальный металл. Материал «металл» здесь главный.
        if color_name in exact_metal_names:
            prompt_template = MATERIAL_PROMPTS.get(color_name, MATERIAL_PROMPTS["metal"])
        elif color_name in bright_colors:
            prompt_template = MATERIAL_PROMPTS["metal"].replace("bright ", "").replace("vivid ", "")
        else:
            prompt_template = MATERIAL_PROMPTS["bronze"] if color_name == "bronze" else MATERIAL_PROMPTS["metal"]
        prompt = prompt_template.format(color=exact_color_desc, object=object_name)
    else:
        # Любой другой материал (дерево, пластик, ткань, кожа, стекло, керамика, бетон):
        # используем шаблон выбранного материала, цвет задаётся именем color_name.
        # Материал имеет приоритет над тем, как назван цвет, чтобы, например,
        # коричневый или серебристый цвет не превращал дерево/пластик в металл.
        prompt_template = MATERIAL_PROMPTS.get(material, DEFAULT_PROMPT)
        if color_name in bright_colors:
            prompt_template = prompt_template.replace("bright ", "").replace("vivid ", "")
        prompt = prompt_template.format(color=exact_color_desc, object=object_name)

    # Эффект старения (патина) для металла: добавляем признаки износа/окисления
    if material == "metal" and patina:
        prompt += ", with aged patina finish, weathered oxidation, antique worn metal, subtle verdigris and brown patina, realistic aging, uneven discolored surface"

    logger.info(f"   object_name: '{object_name}', color_name: '{color_name}', color_hex: '{hex_color_str}'")
    logger.info(f"   Prompt: {prompt}")

    # 5. Создание маски PIL
    mask_pil = Image.fromarray((best_mask * 255).astype(np.uint8), mode='L')
    if mask_pil is None:
        logger.error("❌ mask_pil is None before generation")
        raise HTTPException(500, "Internal error: mask generation failed")

    # Проверяем все переменные перед инференсом
    logger.info(
        f"   Pre-gen check: source_image={type(source_image).__name__}, "
        f"mask_pil={type(mask_pil).__name__}, source_image_np shape={source_image_np.shape}"
    )

    # 6. Инференс с FLUX.2 [klein] 4B
    logger.info(f"    source_image type: {type(source_image)}, size: {source_image.size}")
    if mask_pil is None:
        logger.error("❌ mask_pil is None before generation")
        raise HTTPException(500, "mask_pil is None before generation")

    # Используем параметры из запроса с разумными ограничениями.
    # Примечание: Flux2KleinInpaintPipeline — guidance-distilled модель; для неё
    # guidance_scale > 1.0 игнорируется (см. do_classifier_free_guidance в исходниках).
    # Поэтому здесь значение передаётся «как есть», но реального эффекта при distilled=True не даёт.
    effective_steps = min(50, int(num_inference_steps))
    effective_guidance = guidance_scale if guidance_scale > 0 else 1.0
    effective_strength = strength if strength is not None else 1.0

    gen_start = time.time()
    logger.info(
        f"   Generation params: guidance_scale={effective_guidance}, steps={effective_steps}, strength={effective_strength}, prompt='{prompt}'"
    )
    logger.info(f"🎨 Running FLUX.2 inference: steps={effective_steps}, guidance={effective_guidance}, strength={effective_strength}, image_size={source_image.size}")

    try:
        result = _pipe(
            image=source_image,
            mask_image=mask_pil,
            prompt=prompt,
            guidance_scale=effective_guidance,
            num_inference_steps=effective_steps,
            strength=effective_strength,
            generator=torch.Generator(_device).manual_seed(secrets.randbelow(2**32)),
        ).images[0]
    except torch.cuda.OutOfMemoryError as e:
        logger.error(f"❌ CUDA OOM: {e}. Try lower resolution or enable_sequential_cpu_offload()")
        raise HTTPException(500, "GPU out of memory. Try lowering the image resolution.")
    except Exception as e:
        logger.error(f"❌ Generation error: {e}")
        raise HTTPException(500, f"Generation failed: {e}")

    gen_time = time.time() - gen_start
    logger.info(f"   Generation took {gen_time:.2f}s")

    # 8. Точная подгонка цвета под пипетку (вариант 2):
    # подтягиваем средний цвет замаскированной области к целевому color_hex,
    # сохраняя текстуру/блики от FLUX. Работает ТОЛЬКО когда цвет взят пипеткой.
    if from_pipette and None not in (color_r, color_g, color_b) and best_mask is not None:
        try:
            result_np = np.array(result, dtype=np.float32)
            mask = best_mask.astype(bool)
            target = np.array([color_r, color_g, color_b], dtype=np.float32)
            region = result_np[mask]
            if region.size > 0:
                mean = region.mean(axis=0)
                # сила подгонки: 0.85 — близко к целевому, но оставляем объём
                shift = (target - mean) * 0.85
                result_np[mask] = np.clip(region + shift, 0, 255)
                result = Image.fromarray(result_np.astype(np.uint8))
                logger.info(f"   Applied pipette color-match to target {target.tolist()}")
        except Exception as e:
            logger.warning(f"⚠️  Pipette color-match skipped: {e}")

    # 9. Возврат PNG
    buf = BytesIO()
    result.save(buf, format="PNG")
    buf.seek(0)
    total_time = time.time() - start_time
    logger.info(f"✅ Request completed in {total_time:.2f}s total")

    # Очистка памяти после обработки
    del source_image_np
    del masks, scores, logits, best_mask
    del source_image, mask_pil, result

    response_content = buf.getvalue()
    buf.close()

    if torch.cuda.is_available():
        torch.cuda.empty_cache()
        torch.cuda.synchronize()
    global _request_counter
    _request_counter += 1
    if _request_counter % 10 == 0:
        gc.collect()

    return response_content
