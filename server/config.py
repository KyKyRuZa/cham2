import os
import re
from slowapi import Limiter
from slowapi.util import get_remote_address

# ---------- Ограничения безопасности ----------
MAX_IMAGE_SIZE_BYTES = 20 * 1024 * 1024
MAX_IMAGE_DIMENSION = 8192

ALLOWED_MATERIALS = {
    "metal", "wood", "plastic", "fabric", "glass",
    "leather", "ceramic", "concrete", "bronze",
    "no_texture",
}

_origins_env = os.getenv("ALLOWED_ORIGINS", "").strip()
ALLOWED_ORIGINS = [o.strip() for o in _origins_env.split(",") if o.strip()]

_api_keys_env = os.getenv("API_KEYS", "").strip()
VALID_API_KEYS = {k.strip() for k in _api_keys_env.split(",") if k.strip()}

# Rate limiter: ограничение количества запросов с одного IP
limiter = Limiter(key_func=get_remote_address)

# Таймаут на инференс (секунды). Переопределяется через env REQUEST_TIMEOUT.
REQUEST_TIMEOUT = int(os.getenv("REQUEST_TIMEOUT", "90"))
