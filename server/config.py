import torch

from logger import get_logger

logger = get_logger(__name__)


# ---------- Параметры SAM-2 ----------
SAM2_MODEL_NAME = "facebook/sam2.1-hiera-large"
# Количество джиттер-прогонов для consistency-check сегментации
SAM2_JITTER_OFFSETS = [(8, 0), (-8, 0), (0, 8), (0, -8)]
# Порог согласованности масок (mean IoU). Ниже — предупреждение
SAM2_MIN_CONSISTENCY_IOU = 0.5
# Минимально допустимая площадь маски в пикселях
SAM2_MIN_MASK_AREA = 10
# Доля прогонов (джиттер-точек), подтверждающих пиксель, чтобы он попал
# в финальную маску. Консенсус отсекает нестабильный «ореол» вокруг
# тонких объектов (провода), который раздувает выделение.
SAM2_MASK_CONSENSUS = 0.5
# Мин. доля площади консенсусной маски относительно лучшей одиночной.
# Ниже — откат к одиночной маске (сегментация нестабильна/аморфна).
SAM2_MASK_CONSENSUS_MIN_RATIO = 0.3


# ---------- Параметры FLUX.2 [klein] 4B ----------
FLUX_MODEL_NAME = "black-forest-labs/FLUX.2-klein-4B"
FLUX_TORCH_DTYPE = torch.bfloat16
# Ограничения параметров инференса (совпадают с дефолтами форм)
FLUX_MAX_STEPS = 50
FLUX_DEFAULT_GUIDANCE_SCALE = 5.0
FLUX_DEFAULT_NUM_INFERENCE_STEPS = 30
FLUX_DEFAULT_STRENGTH = 1.0
# Минимально допустимый guidance_scale для distilled-модели
FLUX_MIN_GUIDANCE_SCALE = 1.5
FLUX_FALLBACK_GUIDANCE_SCALE = 3.5


# ---------- Безопасность / ограничения ----------
MAX_IMAGE_SIZE_BYTES = 20 * 1024 * 1024
MAX_IMAGE_DIMENSION = 8192

ALLOWED_MATERIALS = {
    "metal", "wood", "plastic", "fabric", "glass",
    "leather", "ceramic", "concrete", "bronze",
    "no_texture",
}

# Максимальный размер изображения для ресайза перед инференсом
MAX_INFERENCE_SIZE = 1024


# ---------- Промпты по материалам ----------
MATERIAL_PROMPTS = {
    "metal": "The {object} is recolored to {color} metal, same shape, same geometry, same metallic reflections, same lighting, same perspective, photorealistic, rich {color} metallic surface, highly detailed",
    "silver": "The {object} is recolored to polished silver metal, same shape, same geometry, same bright metallic reflections, same lighting, same perspective, photorealistic, mirror-like {color} silver metallic surface, highly reflective",
    "stainless_steel": "The {object} is recolored to brushed stainless steel, same shape, same geometry, same metallic reflections, same lighting, same perspective, photorealistic, clean {color} stainless steel with subtle brushed texture, reflective surface",
    "gold": "The {object} is recolored to shiny gold metal, same shape, same geometry, same bright metallic reflections, same lighting, same perspective, photorealistic, lustrous {color} golden metallic surface, highly reflective",
    "bronze": "The {object} is recolored to bright bronze metal, same shape, same geometry, same shiny metallic reflections, same lighting, same perspective, photorealistic, rich bright bronze metallic surface, highly detailed",
    "brass": "The {object} is recolored to brass metal, same shape, same geometry, same yellow metallic reflections, same lighting, same perspective, photorealistic, warm {color} brass metallic surface, highly reflective",
    "copper": "The {object} is recolored to copper metal, same shape, same geometry, same reddish metallic reflections, same lighting, same perspective, photorealistic, rich {color} copper metallic surface with warm tone, highly detailed",
    "titanium": "The {object} is recolored to deep gray-steel titanium metal, same shape, same geometry, same deep gray-steel metallic reflections, same lighting, same perspective, photorealistic, smooth deep gray-steel metallic surface, highly reflective",
    "wood": "The {object} is recolored to {color} wooden, same shape, same wood grain texture, same lighting, same perspective, photorealistic, deep {color} wood finish, natural look",
    "plastic": "The {object} is recolored to {color} plastic, same shape, same smooth glossy surface, same lighting, same perspective, photorealistic, bright {color} color, high quality",
    "fabric": "The {object} is recolored to {color} fabric, same shape, same weave texture, same folds, same lighting, same perspective, photorealistic, rich {color} textile, high quality",
    "glass": "The {object} is recolored to {color} tinted glass, same shape, same transparency, same reflections, same lighting, same perspective, photorealistic, elegant {color} glass",
    "leather": "The {object} is recolored to {color} leather, same shape, same grain texture, same stitching, same lighting, same perspective, photorealistic, premium {color} leather",
    "ceramic": "The {object} is recolored to {color} ceramic, same shape, same glaze finish, same lighting, same perspective, photorealistic, smooth {color} ceramic",
    "concrete": "The {object} is recolored to {color} concrete, same shape, same rough texture, same lighting, same perspective, photorealistic, industrial {color} concrete surface",
    "no_texture": "The {object} is recolored to {color}, same shape, flat {color} color, no texture, smooth matte surface, photorealistic, solid {color} color, clean finish",
}

DEFAULT_PROMPT = "The {object} is recolored to {color}, same shape, matching the requested material, same lighting, same perspective, photorealistic, beautiful {color} color, highly detailed"

BRIGHTNESS_MODIFIERS = {
    "very dark": (0.0, 0.25),
    "dark": (0.25, 0.40),
    "medium": (0.40, 0.60),
    "bright": (0.60, 0.80),
    "very bright": (0.80, 1.0),
}

# Цвета, где не нужно усиливать словом "bright"
BRIGHT_COLORS = {"light blue", "light coral", "light pink", "white", "off white", "yellow", "aqua", "cyan", "light gray"}

# Точные имена металлов
EXACT_METAL_NAMES = {"gold", "silver", "bronze", "stainless_steel", "brass", "copper", "titanium"}


# ---------- Таблица CSS4/X11 цветов ----------
_CSS_NAMED_COLORS = [
    ((255, 0, 0), "red"),
    ((220, 20, 60), "crimson"),
    ((255, 0, 0), "red"),
    ((128, 0, 0), "maroon"),
    ((178, 34, 34), "firebrick"),
    ((139, 0, 0), "dark red"),
    ((165, 42, 42), "brown"),
    ((178, 34, 34), "firebrick"),
    ((205, 92, 92), "indian red"),
    ((240, 128, 128), "light coral"),
    ((250, 128, 114), "salmon"),
    ((255, 99, 71), "tomato"),
    ((255, 69, 0), "orange red"),
    ((255, 140, 0), "dark orange"),
    ((255, 165, 0), "orange"),
    ((210, 105, 30), "chocolate"),
    ((139, 69, 19), "saddle brown"),
    ((160, 82, 45), "sienna"),
    ((205, 133, 63), "peru"),
    ((222, 184, 135), "burlywood"),
    ((244, 164, 96), "sandy brown"),
    ((184, 134, 11), "dark goldenrod"),
    ((255, 215, 0), "gold"),
    ((218, 165, 32), "goldenrod"),
    ((255, 223, 0), "gold"),
    ((189, 183, 107), "dark khaki"),
    ((240, 230, 140), "khaki"),
    ((255, 250, 205), "lemon chiffon"),
    ((255, 255, 0), "yellow"),
    ((154, 205, 50), "yellow green"),
    ((128, 128, 0), "olive"),
    ((0, 128, 0), "green"),
    ((0, 100, 0), "dark green"),
    ((34, 139, 34), "forest green"),
    ((107, 142, 35), "olive green"),
    ((50, 205, 50), "lime green"),
    ((144, 238, 144), "light green"),
    ((0, 255, 0), "lime"),
    ((60, 179, 113), "medium sea green"),
    ((46, 139, 87), "sea green"),
    ((32, 178, 170), "light sea green"),
    ((0, 206, 209), "dark turquoise"),
    ((64, 224, 208), "turquoise"),
    ((0, 255, 255), "cyan"),
    ((175, 238, 238), "pale turquoise"),
    ((127, 255, 212), "aquamarine"),
    ((0, 128, 128), "teal"),
    ((0, 191, 255), "deep sky blue"),
    ((135, 206, 235), "sky blue"),
    ((70, 130, 180), "steel blue"),
    ((95, 158, 160), "cadet blue"),
    ((100, 149, 237), "cornflower blue"),
    ((30, 144, 255), "dodger blue"),
    ((65, 105, 225), "royal blue"),
    ((0, 0, 255), "blue"),
    ((0, 0, 205), "medium blue"),
    ((0, 0, 139), "navy blue"),
    ((25, 25, 112), "midnight blue"),
    ((72, 61, 139), "dark slate blue"),
    ((106, 90, 205), "slate blue"),
    ((123, 104, 238), "medium slate blue"),
    ((138, 43, 226), "blue violet"),
    ((148, 0, 211), "dark violet"),
    ((75, 0, 130), "indigo"),
    ((153, 50, 204), "dark orchid"),
    ((186, 85, 211), "medium orchid"),
    ((0, 0, 128), "navy"),
    ((238, 130, 238), "violet"),
    ((255, 0, 255), "magenta"),
    ((199, 21, 133), "medium violet red"),
    ((219, 112, 147), "pale violet red"),
    ((255, 20, 147), "deep pink"),
    ((255, 105, 180), "hot pink"),
    ((255, 192, 203), "pink"),
    ((255, 182, 193), "light pink"),
    ((255, 0, 255), "fuchsia"),
    ((221, 160, 221), "plum"),
    ((238, 130, 238), "violet"),
    ((165, 42, 42), "brown"),
    ((139, 69, 19), "saddle brown"),
    ((160, 82, 45), "sienna"),
    ((210, 105, 30), "chocolate"),
    ((205, 133, 63), "peru"),
    ((205, 127, 50), "bronze"),
    ((222, 184, 135), "burlywood"),
    ((244, 164, 96), "sandy brown"),
    ((201, 166, 107), "brass"),
    ((205, 127, 50), "copper"),
    ((192, 192, 192), "silver"),
    ((211, 211, 211), "light gray"),
    ((119, 136, 153), "light slate gray"),
    ((105, 105, 105), "dim gray"),
    ((250, 250, 250), "snow"),
    ((28, 28, 28), "dim gray"),
    ((0, 77, 64), "dark green"),
    ((93, 64, 55), "dark brown"),
    ((62, 39, 35), "espresso"),
    ((44, 62, 80), "charcoal blue"),
]

_GRAY_COLORS = [
    (0.92, "white"),
    (0.80, "off white"),
    (0.72, "light gray"),
    (0.58, "silver"),
    (0.42, "dark gray"),
    (0.28, "gray"),
    (0.12, "dim gray"),
    (0.04, "black"),
]

# Специальные серые цвета металлов по точному RGB
_EXACT_METAL_GRAYS = {
    (232, 236, 239): "stainless_steel",
    (224, 224, 224): "silver",
    (110, 116, 120): "titanium",
}

# Точные серые цвета по RGB
_EXACT_GRAYS = {
    (255, 255, 255): "white",
    (128, 128, 128): "gray",
    (211, 211, 211): "light gray",
    (169, 169, 169): "dark gray",
    (105, 105, 105): "dim gray",
}

# Цвета, для которых возвращаем имя как есть (без уточнения яркости)
_EXACT_COLOR_NAMES = {
    "black", "white", "red", "green", "blue", "yellow", "cyan", "magenta",
    "orange", "purple", "pink", "brown", "gray", "maroon", "olive", "teal",
    "navy blue", "midnight blue", "dark red", "dark green", "dark blue",
    "light blue", "light green", "light pink", "light coral", "dim gray",
    "dark gray", "light gray", "off white", "silver", "snow",
    "lime", "aqua", "crimson", "firebrick", "indian red", "salmon", "tomato",
    "gold", "goldenrod", "khaki", "lemon chiffon", "yellow green",
    "dark olive green", "forest green", "olive green", "lime green",
    "light sea green", "dark turquoise", "turquoise", "cyan",
    "pale turquoise", "aquamarine", "teal",
    "deep sky blue", "sky blue", "steel blue", "cornflower blue", "dodger blue",
    "royal blue", "medium blue", "navy",
    "dark slate blue", "slate blue", "medium slate blue", "blue violet",
    "dark violet", "indigo", "dark orchid", "medium orchid", "violet",
    "magenta", "medium violet red", "pale violet red", "deep pink",
    "hot pink", "pink", "light pink", "fuchsia", "plum",
    "saddle brown", "sienna", "chocolate", "peru", "burlywood", "sandy brown",
    "dark goldenrod", "dark khaki", "dark green", "dark brown", "espresso",
    "charcoal blue", "light slate gray",
    "stainless_steel", "bronze",
}

logger.info("Config loaded: SAM-2=%s, FLUX-2=%s", SAM2_MODEL_NAME, FLUX_MODEL_NAME)
