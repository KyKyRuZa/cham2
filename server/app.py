import logging
import signal
import time
import torch
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded

from server.config import ALLOWED_ORIGINS, limiter
from server.state import _predictor, _pipe, _device, _request_counter, _shutdown_event
from server.routes.ai import router as ai_router

logger = logging.getLogger(__name__)

_shutdown_event = None


def _register_signals():
    """Регистрирует обработчики SIGTERM/SIGINT для graceful shutdown."""
    try:
        def handle_signal(signum, frame):
            logger.info(f"Received signal {signum}, initiating graceful shutdown...")
            _shutdown_event.set()

        signal.signal(signal.SIGTERM, handle_signal)
        signal.signal(signal.SIGINT, handle_signal)
    except Exception as e:
        logger.warning(f"Could not register signal handlers: {e}")


@asynccontextmanager
async def lifespan(app: FastAPI):
    global _predictor, _pipe, _device
    _device = "cuda" if torch.cuda.is_available() else "cpu"
    logger.info(f"Using device: {_device}")

    _register_signals()

    # Загрузка SAM-2
    try:
        from sam2.sam2_image_predictor import SAM2ImagePredictor
        _predictor = SAM2ImagePredictor.from_pretrained("facebook/sam2.1-hiera-large")
        _predictor.model = _predictor.model.to(_device).eval()
        logger.info("✅ SAM-2 Hiera-L loaded")
    except Exception as e:
        logger.error(f"❌ SAM-2 load error: {e}")
        _predictor = None

    # Загрузка FLUX.2 [klein] 4B (Apache 2.0)
    try:
        from diffusers import Flux2KleinInpaintPipeline
        _pipe = Flux2KleinInpaintPipeline.from_pretrained(
            "black-forest-labs/FLUX.2-klein-4B",
            torch_dtype=torch.bfloat16
        )
        _pipe.to(_device)
        logger.info("✅ FLUX.2 [klein] 4B loaded")
    except Exception as e:
        logger.error(f"❌ FLUX.2 load error: {e}")
        _pipe = None

    yield

    # Ожидаем завершения текущих запросов (макс 30 сек)
    if _shutdown_event is not None:
        try:
            import asyncio
            await asyncio.wait_for(_shutdown_event.wait(), timeout=30)
        except asyncio.TimeoutError:
            logger.warning("Graceful shutdown timed out after 30s, forcing exit")

    # Очистка при завершении
    if torch.cuda.is_available():
        torch.cuda.empty_cache()
        logger.info("🧹 GPU cache cleared")
    logger.info("🛑 Server stopped")


app = FastAPI(title="AI Colorization API", version="2.0.0", lifespan=lifespan)

app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=bool(ALLOWED_ORIGINS),
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type", "X-API-Key"],
)

app.include_router(ai_router)


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)