import os
import time
import traceback
import gc
import math
import re
import secrets
import numpy as np
import torch
from io import BytesIO
from contextlib import asynccontextmanager
from diffusers import Flux2KleinInpaintPipeline
from fastapi import Depends, FastAPI, File, Form, Header, HTTPException, Request, UploadFile
from fastapi.responses import Response
from PIL import Image, ImageOps
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.util import get_remote_address

try:
    from dotenv import load_dotenv
    load_dotenv()
except Exception:
    pass

from logger import get_logger
from config import (
    SAM2_MODEL_NAME, SAM2_JITTER_OFFSETS, SAM2_MIN_CONSISTENCY_IOU, SAM2_MIN_MASK_AREA,
    FLUX_MODEL_NAME, FLUX_TORCH_DTYPE,
    FLUX_MAX_STEPS, FLUX_DEFAULT_GUIDANCE_SCALE, FLUX_DEFAULT_NUM_INFERENCE_STEPS,
    FLUX_DEFAULT_STRENGTH, FLUX_MIN_GUIDANCE_SCALE, FLUX_FALLBACK_GUIDANCE_SCALE,
    MAX_IMAGE_SIZE_BYTES, MAX_IMAGE_DIMENSION, MAX_INFERENCE_SIZE,
    ALLOWED_MATERIALS, MATERIAL_PROMPTS, DEFAULT_PROMPT, BRIGHT_COLORS, EXACT_METAL_NAMES,
    _CSS_NAMED_COLORS, _GRAY_COLORS, _EXACT_METAL_GRAYS, _EXACT_GRAYS, _EXACT_COLOR_NAMES,
)

logger = get_logger(__name__)


# ---------- Ограничения безопасности (ключи доступа) ----------
_api_keys_env = os.getenv("API_KEYS", "").strip()
VALID_API_KEYS = {k.strip() for k in _api_keys_env.split(",") if k.strip()}

# Rate limiter: ограничение количества запросов с одного IP
limiter = Limiter(key_func=get_remote_address)


def sanitize_prompt_text(text: str, max_length: int = 50) -> str:
    if not text:
        return "object"
    cleaned = re.sub(r"[^\w\s-]", "", text, flags=re.UNICODE).strip()
    cleaned = cleaned[:max_length]
    return cleaned or "object"


def mask_iou(mask_a: np.ndarray, mask_b: np.ndarray) -> float:
    intersection = np.logical_and(mask_a, mask_b).sum()
    union = np.logical_or(mask_a, mask_b).sum()
    if union == 0:
        return 0.0
    return float(intersection / union)


# --------------------- Lifespan ---------------------
@asynccontextmanager
async def lifespan(app: FastAPI):
    global _predictor, _pipe, _device
    _device = "cuda" if torch.cuda.is_available() else "cpu"
    logger.info(f"Using device: {_device}")

    try:
        from sam2.sam2_image_predictor import SAM2ImagePredictor
        _predictor = SAM2ImagePredictor.from_pretrained(SAM2_MODEL_NAME)
        _predictor.model = _predictor.model.to(_device).eval()
        logger.info("✅ SAM-2 Hiera-L loaded")
    except Exception as e:
        logger.error(f"❌ SAM-2 load error: {e}")
        _predictor = None

    try:
        _pipe = Flux2KleinInpaintPipeline.from_pretrained(
            FLUX_MODEL_NAME,
            torch_dtype=FLUX_TORCH_DTYPE
        )
        _pipe.to("cuda")
        logger.info("✅ FLUX.2 [klein] 4B loaded")
    except Exception as e:
        logger.error(f"❌ FLUX.2 load error: {e}")
        _pipe = None

    yield

    # Очистка при завершении
    if torch.cuda.is_available():
        torch.cuda.empty_cache()
        logger.info("🧹 GPU cache cleared")


app = FastAPI(title="AI Colorization API", version="2.0.0", lifespan=lifespan)

def _rate_limit_handler(request: Request, exc: RateLimitExceeded):
    logger.warning(f"⛔ Rate limit exceeded for {get_remote_address(request)}")
    return _rate_limit_exceeded_handler(request, exc)

app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_handler)

_predictor = None
_pipe = None
_device = "cpu"


# --------------------- Проверка API-ключа ---------------------
def verify_api_key(x_api_key: str | None = Header(default=None, alias="X-API-Key")):
    """Проверяет API-ключ из заголовка X-API-Key.
    Если серверные ключи не заданы (VALID_API_KEYS пуст), проверка пропускается."""
    if not VALID_API_KEYS:
        return None
    if not x_api_key or x_api_key not in VALID_API_KEYS:
        logger.warning("⛔ Rejected request with invalid/missing API key")
        raise HTTPException(status_code=401, detail="Invalid or missing API key")
    return x_api_key


# --------------------- Подбор имени цвета ---------------------
def get_color_hex_name(hex_color: int) -> str:
    """Конвертирует HEX-цвет в точное читаемое английское название для промпта.
    Использует lookup цветов CSS4/X11 с поиском ближайшего в RGB-пространстве."""
    r = (hex_color >> 16) & 0xFF
    g = (hex_color >> 8) & 0xFF
    b = hex_color & 0xFF
    mx = max(r, g, b)
    mn = min(r, g, b)
    sat = 0.0 if mx == 0 else (mx - mn) / mx

    # Серые оттенки
    if sat < 0.12:
        val = mx / 255.0
        if (r, g, b) in _EXACT_METAL_GRAYS:
            return _EXACT_METAL_GRAYS[(r, g, b)]
        if (r, g, b) in _EXACT_GRAYS:
            return _EXACT_GRAYS[(r, g, b)]
        for threshold, name in _GRAY_COLORS:
            if val >= threshold:
                return name
        return "black"

    # Находим ближайший цвет из таблицы по евклидову расстоянию в RGB
    best_name = _CSS_NAMED_COLORS[0][1]
    best_dist = float('inf')
    for (cr, cg, cb), name in _CSS_NAMED_COLORS:
        dr = r - cr
        dg = g - cg
        db = b - cb
        dist = dr * dr + dg * dg + db * db
        if dist < best_dist:
            best_dist = dist
            best_name = name

    if best_name in _EXACT_COLOR_NAMES or best_dist < 2500:
        return best_name

    val = mx / 255.0
    if val < 0.30:
        return "very dark " + best_name
    elif val < 0.45:
        return "dark " + best_name
    elif val > 0.80:
        return "bright " + best_name
    return best_name


@app.get("/health")
async def health():
    return {
        "status": "healthy",
        "device": _device,
        "models_loaded": _predictor is not None and _pipe is not None
    }


def run_recolor_job(
    img_bytes: bytes,
    point_x: float,
    point_y: float,
    material: str,
    color_hex: str,
    color_name: str,
    object_name: str,
    strength: float,
    guidance_scale: float,
    num_inference_steps: int,
    patina: bool,
    color_r: int | None = None,
    color_g: int | None = None,
    color_b: int | None = None,
    from_pipette: bool = False,
) -> bytes:
    """Синхронная тяжёлая обработка одного запроса (декод, SAM-2, FLUX, кодирование PNG).

    Вызывается напрямую из эндпоинта ``ai_recolor``.
    """
    start_time = time.time()

    # 1. Декодирование изображения
    try:
        source_image = Image.open(BytesIO(img_bytes))
        source_image = ImageOps.exif_transpose(source_image)
        source_image = source_image.convert("RGB")
    except Exception as e:
        logger.error(f"❌ PIL decode error: {e}")
        raise HTTPException(400, f"Invalid image: {e}")
    if source_image is None:
        logger.error("❌ Failed to decode image: source_image is None")
        raise HTTPException(400, "Failed to decode image")
    w, h = source_image.size
    logger.info(f"   Image dimensions: {w}x{h} (EXIF orientation applied server-side)")

    # Ресайз до разумного размера (макс. 1024x1024) для стабильности
    if w > MAX_INFERENCE_SIZE or h > MAX_INFERENCE_SIZE:
        source_image.thumbnail((MAX_INFERENCE_SIZE, MAX_INFERENCE_SIZE))
        if source_image is None:
            logger.error("❌ source_image became None after thumbnail")
            raise HTTPException(500, "Internal error: image resize failed")
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
        color_hex_int = int(color_hex)
    logger.info(f"   Parsed color_hex_int: {color_hex_int}")

    # Проверяем, что source_image всё ещё валидна после всех операций
    logger.info(f"   source_image type before generation: {type(source_image)}, size: {source_image.size if source_image else 'N/A'}")
    if source_image is None:
        logger.error("❌ source_image is None before generation")
        raise HTTPException(500, "Internal error: source_image is None before generation")

    # 3. Сегментация SAM-2 с consistency-check (прогоны с джиттер-точками)
    seg_start = time.time()

    jitter_points = []
    for dx, dy in SAM2_JITTER_OFFSETS:
        jx = max(0, min(image_width - 1, point_x + dx))
        jy = max(0, min(image_height - 1, point_y + dy))
        jitter_points.append((jx, jy))

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
    if best_mean_iou < SAM2_MIN_CONSISTENCY_IOU:
        logger.warning(f"⚠️  Low mask consistency (mean IoU={best_mean_iou:.3f} < {SAM2_MIN_CONSISTENCY_IOU}) — point may be near object boundary")

    if mask_area < SAM2_MIN_MASK_AREA:
        logger.warning("⚠️  Mask area is very small – object might not be detected!")

    seg_time = time.time() - seg_start
    logger.info(f"   Segmentation took {seg_time:.2f}s ({len(all_coords)} runs with consistency-check)")

    # 4. Формирование промпта с цветом (именованное название) и названием объекта
    if color_name and color_name != "":
        color_name = color_name
    else:
        color_name = get_color_hex_name(color_hex_int)
    hex_color_str = f"#{color_hex_int:06x}"

    if None not in (color_r, color_g, color_b):
        exact_color_desc = f"{hex_color_str} (RGB {color_r}, {color_g}, {color_b})"
    else:
        exact_color_desc = hex_color_str

    # Flat-matte только когда материал реально «без текстуры».
    if material == "no_texture":
        prompt = f"The {object_name} is recolored to {exact_color_desc}, same shape, flat {color_name} color, hex {hex_color_str}, no texture, smooth matte surface, photorealistic"
    elif material == "metal":
        if color_name in EXACT_METAL_NAMES:
            prompt_template = MATERIAL_PROMPTS.get(color_name, MATERIAL_PROMPTS["metal"])
        elif color_name in BRIGHT_COLORS:
            prompt_template = MATERIAL_PROMPTS["metal"].replace("bright ", "").replace("vivid ", "")
        else:
            prompt_template = MATERIAL_PROMPTS["bronze"] if color_name == "bronze" else MATERIAL_PROMPTS["metal"]
        prompt = prompt_template.format(color=exact_color_desc, object=object_name)
    else:
        prompt_template = MATERIAL_PROMPTS.get(material, DEFAULT_PROMPT)
        if color_name in BRIGHT_COLORS:
            prompt_template = prompt_template.replace("bright ", "").replace("vivid ", "")
        prompt = prompt_template.format(color=exact_color_desc, object=object_name)

    # Эффект старения (патина) для металла
    if material == "metal" and patina:
        prompt += ", with aged patina finish, weathered oxidation, antique worn metal, subtle verdigris and brown patina, realistic aging, uneven discolored surface"

    logger.info(f"   object_name: '{object_name}', color_name: '{color_name}', color_hex: '{hex_color_str}'")
    logger.info(f"   Prompt: {prompt}")

    # 5. Создание маски PIL
    mask_pil = Image.fromarray((best_mask * 255).astype(np.uint8), mode='L')
    if mask_pil is None:
        logger.error("❌ mask_pil is None before generation")
        raise HTTPException(500, "Internal error: mask generation failed")

    # Используем параметры из запроса с разумными ограничениями.
    # Примечание: Flux2KleinInpaintPipeline — guidance-distilled модель; для неё
    # guidance_scale > 1.0 игнорируется (см. do_classifier_free_guidance в исходниках).
    effective_steps = min(FLUX_MAX_STEPS, int(num_inference_steps))
    effective_guidance = guidance_scale if guidance_scale > 0 else 1.0
    effective_strength = strength if strength is not None else FLUX_DEFAULT_STRENGTH

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

    # 8. Точная подгонка цвета под пипетку
    if from_pipette and None not in (color_r, color_g, color_b) and best_mask is not None:
        try:
            result_np = np.array(result, dtype=np.float32)
            mask = best_mask.astype(bool)
            target = np.array([color_r, color_g, color_b], dtype=np.float32)
            region = result_np[mask]
            if region.size > 0:
                mean = region.mean(axis=0)
                # Защита от деления на ~0 (почти чёрный регион)
                mean_safe = np.where(mean < 1.0, 1.0, mean)
                # Мультипликативная коррекция (white balance) вместо плоского
                # аддитивного сдвига: масштабирует каждый канал, сохраняя
                # структуру/текстуру региона и меняя баланс каналов под цель.
                ratio = target / mean_safe
                k = 0.9
                corrected = region * (1.0 - k + k * ratio)
                result_np[mask] = np.clip(corrected, 0, 255)
                result = Image.fromarray(result_np.astype(np.uint8))
                logger.info(f"   Applied pipette white-balance match to target {target.tolist()} (ratio={ratio.tolist()})")
        except Exception as e:
            logger.warning(f"⚠️  Pipette color-match skipped: {e}")

    # 9. Возврат PNG
    buf = BytesIO()
    result.save(buf, format="PNG")
    buf.seek(0)

    # Очистка памяти после обработки
    del source_image_np
    del masks, scores, logits, best_mask
    del source_image, mask_pil, result

    response_content = buf.getvalue()
    buf.close()

    if torch.cuda.is_available():
        torch.cuda.empty_cache()
        torch.cuda.synchronize()
    gc.collect()

    total_time = time.time() - start_time
    logger.info(f"✅ Recolor job finished in {total_time:.2f}s")

    return response_content


@app.post("/ai-recolor")
@limiter.limit("10/minute")
async def ai_recolor(
    request: Request,
    image: UploadFile = File(...),
    point_x: float = Form(...),
    point_y: float = Form(...),
    material: str = Form("wood"),
    color_hex: str = Form("0xFF8B4513"),
    color_name: str = Form(""),
    color_r: int | None = Form(None),
    color_g: int | None = Form(None),
    color_b: int | None = Form(None),
    object_name: str = Form("object"),
    strength: float = Form(FLUX_DEFAULT_STRENGTH),
    guidance_scale: float = Form(FLUX_DEFAULT_GUIDANCE_SCALE),
    num_inference_steps: int = Form(FLUX_DEFAULT_NUM_INFERENCE_STEPS),
    patina: bool = Form(False),
    from_pipette: bool = Form(False),
    api_key: str | None = Depends(verify_api_key),
):
    start_time = time.time()
    logger.info("📥 ===== NEW REQUEST =====")
    logger.debug(f"   Filename: {image.filename}")
    logger.debug(f"   point_x: {point_x}, point_y: {point_y}")
    logger.debug(f"   object_name: {object_name}, material: {material}, color_hex: {color_hex}, color_name: {color_name}, color_rgb: ({color_r}, {color_g}, {color_b}), strength: {strength}, guidance_scale: {guidance_scale}, steps: {num_inference_steps}, patina: {patina}")

    # --- Валидация входящих параметров (защита от аномальных значений/DoS) ---
    for _name, _val in (
        ("point_x", point_x), ("point_y", point_y),
        ("strength", strength), ("guidance_scale", guidance_scale),
    ):
        if not math.isfinite(_val):
            logger.warning(f"⚠️ Validation failed: parameter '{_name}' is not finite")
            raise HTTPException(400, f"Parameter '{_name}' must be a finite number")

    if not (0 <= point_x <= MAX_IMAGE_DIMENSION) or not (0 <= point_y <= MAX_IMAGE_DIMENSION):
        logger.warning(f"⚠️ Validation failed: point out of range ({point_x}, {point_y})")
        raise HTTPException(400, "point_x/point_y out of allowed range")

    strength = float(min(1.0, max(0.1, strength)))
    guidance_scale = float(min(20.0, max(1.0, guidance_scale)))
    if num_inference_steps < 6 or num_inference_steps > 50:
        logger.warning(f"⚠️ num_inference_steps={num_inference_steps} out of range, clamping to [6,50]")
    num_inference_steps = int(min(50, max(6, num_inference_steps)))

    if material not in ALLOWED_MATERIALS:
        logger.warning(f"⚠️ Unknown material '{material}', falling back to 'wood'")
        material = "wood"

    object_name = sanitize_prompt_text(object_name)

    if guidance_scale < FLUX_MIN_GUIDANCE_SCALE:
        logger.warning(f"⚠️ guidance_scale={guidance_scale} too low, clamping to {FLUX_FALLBACK_GUIDANCE_SCALE}")
        guidance_scale = FLUX_FALLBACK_GUIDANCE_SCALE

    if _predictor is None or _pipe is None:
        logger.error("❌ Models not loaded")
        raise HTTPException(503, "Models not loaded")

    img_bytes = await image.read()
    logger.info(f"   Image size: {len(img_bytes)} bytes")

    if len(img_bytes) > MAX_IMAGE_SIZE_BYTES:
        logger.warning(
            f"⚠️ Image too large: {len(img_bytes)} bytes "
            f"(limit {MAX_IMAGE_SIZE_BYTES} bytes)"
        )
        raise HTTPException(
            413,
            f"Image too large. Maximum allowed size is "
            f"{MAX_IMAGE_SIZE_BYTES // (1024 * 1024)} MB.",
        )

    try:
        response_content = run_recolor_job(
            img_bytes,
            point_x,
            point_y,
            material,
            color_hex,
            color_name,
            object_name,
            strength,
            guidance_scale,
            num_inference_steps,
            patina,
            color_r,
            color_g,
            color_b,
            from_pipette,
        )
    except HTTPException:
        raise
    except Exception as e:
        total_time = time.time() - start_time
        logger.error(f"❌ Request failed after {total_time:.2f}s: {e}")
        logger.error(traceback.format_exc())
        if torch.cuda.is_available():
            torch.cuda.empty_cache()
        gc.collect()
        raise HTTPException(500, str(e))

    total_time = time.time() - start_time
    logger.info(f"✅ Request completed in {total_time:.2f}s total")
    return Response(content=response_content, media_type="image/png")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)
