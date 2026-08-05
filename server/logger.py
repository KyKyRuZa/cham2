import logging
import os

_LOG_MODE = os.getenv("LOG_MODE", "prod").lower()

if _LOG_MODE == "dev":
    _EFFECTIVE_LEVEL = logging.DEBUG
else:
    _LOG_LEVEL = os.getenv("LOG_LEVEL", "WARNING").upper()
    _EFFECTIVE_LEVEL = getattr(logging, _LOG_LEVEL, logging.WARNING)

logging.basicConfig(
    level=_EFFECTIVE_LEVEL,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler()],
)


def get_logger(name: str) -> logging.Logger:
    """Возвращает именованный логгер с уже настроенным уровнем и форматом."""
    return logging.getLogger(name)
