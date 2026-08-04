import time
import traceback
import logging
import math
import gc
import torch
from fastapi import APIRouter, Depends, File, Form, HTTPException, Request, UploadFile
from fastapi.responses import Response
from server.config import VALID_API_KEYS, ALLOWED_MATERIALS, MAX_IMAGE_SIZE_BYTES, MAX_IMAGE_DIMENSION, REQUEST_TIMEOUT
from server.prompts import sanitize_prompt_text
from server.services.recolor import run_recolor_job, RecolorTask
from server.state import _predictor, _pipe, _device, _shutdown_event
import asyncio

logger = logging.getLogger(__name__)

router = APIRouter()


def verify_api_key(x_api_key: str | None = None):
    """Проверяет API-ключ из заголовка X-API-Key.
    Если серверные ключи не заданы (VALID_API_KEYS пуст), проверка пропускается."""
    if not VALID_API_KEYS:
        return None
    if not x_api_key or x_api_key not in VALID_API_KEYS:
        logger.warning("⛔ Rejected request with invalid/missing API key")
        raise HTTPException(status_code=401, detail="Invalid or missing API key")
    return x_api_key


@router.get("/health")
async def health():
    models_loaded = _predictor is not None and _pipe is not None
    logger.info(f"📊 Health check: device={_device}, predictor={_predictor is not None}, pipe={_pipe is not None}, models_loaded={models_loaded}")
    return {
        "status": "healthy",
        "device": _device,
        "models_loaded": models_loaded,
    }


@router.post("/ai-recolor")
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
    strength: float = Form(1.0),
    guidance_scale: float = Form(5.0),
    num_inference_steps: int = Form(30),
    patina: bool = Form(False),
    from_pipette: bool = Form(False),
    api_key: str | None = Depends(verify_api_key),
):
    start_time = time.time()
    logger.info("📥 ===== NEW REQUEST =====")
    if torch.cuda.is_available():
        alloc = torch.cuda.memory_allocated() / 1024**3
        reserved = torch.cuda.memory_reserved() / 1024**3
        logger.info(f"   GPU memory: allocated={alloc:.2f}GB, reserved={reserved:.2f}GB")
    logger.info(f"   Models: predictor={_predictor is not None}, pipe={_pipe is not None}")
    logger.debug(f"   Filename: {image.filename}")
    logger.debug(f"   point_x: {point_x}, point_y: {point_y}")
    logger.debug(f"   object_name: {object_name}, material: {material}, color_hex: {color_hex}, color_name: {color_name}, color_rgb: ({color_r}, {color_g}, {color_b}), strength: {strength}, guidance_scale: {guidance_scale}, steps: {num_inference_steps}, patina: {patina}")

    if _shutdown_event is not None and _shutdown_event.is_set():
        raise HTTPException(503, "Server is shutting down")

    # --- Валидация входящих параметров (защита от аномальных значений/DoS) ---
    # Отсекаем NaN/Infinity
    for _name, _val in (
        ("point_x", point_x), ("point_y", point_y),
        ("strength", strength), ("guidance_scale", guidance_scale),
    ):
        if not math.isfinite(_val):
            raise HTTPException(400, f"Parameter '{_name}' must be a finite number")

    # Координаты клика: неотрицательные и в разумных пределах
    if not (0 <= point_x <= MAX_IMAGE_DIMENSION) or not (0 <= point_y <= MAX_IMAGE_DIMENSION):
        raise HTTPException(400, "point_x/point_y out of allowed range")

    # strength ограничиваем диапазоном [0.1, 1.0]
    strength = float(min(1.0, max(0.1, strength)))

    # guidance_scale ограничиваем диапазоном [1.0, 20.0]
    guidance_scale = float(min(20.0, max(1.0, guidance_scale)))

    # num_inference_steps ограничиваем диапазоном [6, 50]
    num_inference_steps = int(min(50, max(4, num_inference_steps)))

    # Материал должен быть из разрешённого набора
    if material not in ALLOWED_MATERIALS:
        logger.warning(f"⚠️ Unknown material '{material}', falling back to 'wood'")
        material = "wood"

    # Санитизация пользовательской строки object_name (защита от prompt injection)
    object_name = sanitize_prompt_text(object_name)

    # Валидация параметров инференса
    if guidance_scale < 1.5:
        logger.warning(f"⚠️ guidance_scale={guidance_scale} too low, clamping to 3.5")
        guidance_scale = 3.5

    if _predictor is None or _pipe is None:
        logger.error("❌ Models not loaded")
        raise HTTPException(503, "Models not loaded")

    # Чтение тела запроса (ввод/вывод — асинхронно, не блокирует event loop)
    img_bytes = await image.read()
    logger.info(f"   Image size: {len(img_bytes)} bytes")

    # Проверка размера загружаемого файла (защита от DoS)
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
        task = RecolorTask(
            img_bytes=img_bytes,
            point_x=point_x,
            point_y=point_y,
            material=material,
            color_hex=color_hex,
            color_name=color_name,
            object_name=object_name,
            strength=strength,
            guidance_scale=guidance_scale,
            num_inference_steps=num_inference_steps,
            patina=patina,
            color_r=color_r,
            color_g=color_g,
            color_b=color_b,
            from_pipette=from_pipette,
        )
        response_content = await asyncio.wait_for(
            asyncio.to_thread(run_recolor_job, task),
            timeout=REQUEST_TIMEOUT,
        )
    except HTTPException:
        # Пробрасываем корректные HTTP-ошибки (400/413/503 и т.д.) без подмены на 500
        raise
    except Exception as e:
        total_time = time.time() - start_time
        logger.error(f"❌ Request failed after {total_time:.2f}s")
        logger.error(traceback.format_exc())
        if torch.cuda.is_available():
            torch.cuda.empty_cache()
        gc.collect()
        raise HTTPException(500, "Internal server error")

    total_time = time.time() - start_time
    logger.info(f"✅ Request completed in {total_time:.2f}s total")
    return Response(content=response_content, media_type="image/png")
