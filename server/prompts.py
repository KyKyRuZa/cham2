import logging
import math
import re
import numpy as np

logger = logging.getLogger(__name__)

MATERIAL_PROMPTS = {
    "metal": "The {object} is recolored to {color} metal, same shape, same geometry, same metallic reflections, same lighting, same perspective, photorealistic, rich {color} metallic surface, highly detailed",
    "silver": "The {object} is recolored to polished silver metal, same shape, same geometry, same bright metallic reflections, same lighting, same perspective, photorealistic, mirror-like silver metallic surface, highly reflective",
    "stainless_steel": "The {object} is recolored to brushed stainless steel, same shape, same geometry, same metallic reflections, same lighting, same perspective, photorealistic, clean brushed stainless steel with subtle linear texture, reflective surface",
    "gold": "The {object} is recolored to shiny gold metal, same shape, same geometry, same bright metallic reflections, same lighting, same perspective, photorealistic, lustrous golden metallic surface, highly reflective",
    "bronze": "The {object} is recolored to bright bronze metal, same shape, same geometry, same shiny metallic reflections, same lighting, same perspective, photorealistic, rich bright bronze metallic surface, highly detailed",
    "brass": "The {object} is recolored to brass metal, same shape, same geometry, same yellow metallic reflections, same lighting, same perspective, photorealistic, warm brass metallic surface, highly reflective",
    "copper": "The {object} is recolored to copper metal, same shape, same geometry, same reddish metallic reflections, same lighting, same perspective, photorealistic, rich copper metallic surface with warm tone, highly detailed",
    "titanium": "The {object} is recolored to titanium metal, same shape, same geometry, same metallic reflections, same lighting, same perspective, photorealistic, smooth metallic surface, highly reflective",
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

# CSS4/X11 таблица цветов для поиска ближайшего имени
# Формат: ((R, G, B), name)
_CSS_NAMED_COLORS = [
    # Красный
    ((255, 0, 0), "red"),
    ((220, 20, 60), "crimson"),
    ((128, 0, 0), "maroon"),
    ((178, 34, 34), "firebrick"),
    ((139, 0, 0), "dark red"),
    ((165, 42, 42), "brown"),
    ((205, 92, 92), "indian red"),
    ((240, 128, 128), "light coral"),
    ((250, 128, 114), "salmon"),
    ((255, 99, 71), "tomato"),
    ((255, 69, 0), "orange red"),

    # Оранжевый/коричневый
    ((255, 140, 0), "dark orange"),
    ((255, 165, 0), "orange"),
    ((210, 105, 30), "chocolate"),
    ((139, 69, 19), "saddle brown"),
    ((160, 82, 45), "sienna"),
    ((205, 133, 63), "peru"),
    ((222, 184, 135), "burlywood"),
    ((244, 164, 96), "sandy brown"),
    ((184, 134, 11), "dark goldenrod"),

    # Жёлтый/золотой
    ((255, 215, 0), "gold"),
    ((218, 165, 32), "goldenrod"),
    ((189, 183, 107), "dark khaki"),
    ((240, 230, 140), "khaki"),
    ((255, 250, 205), "lemon chiffon"),
    ((255, 255, 0), "yellow"),
    ((154, 205, 50), "yellow green"),
    ((128, 128, 0), "olive"),

    # Зелёный
    ((0, 128, 0), "green"),
    ((0, 100, 0), "dark green"),
    ((34, 139, 34), "forest green"),
    ((107, 142, 35), "olive green"),
    ((50, 205, 50), "lime green"),
    ((144, 238, 144), "light green"),
    ((0, 255, 0), "lime"),
    ((60, 179, 113), "medium sea green"),
    ((46, 139, 87), "sea green"),

    # Бирюзовый/циан
    ((32, 178, 170), "light sea green"),
    ((0, 206, 209), "dark turquoise"),
    ((64, 224, 208), "turquoise"),
    ((0, 255, 255), "cyan"),
    ((175, 238, 238), "pale turquoise"),
    ((127, 255, 212), "aquamarine"),
    ((0, 128, 128), "teal"),

    # Синий
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

    # Фиолетовый
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

    # Розовый/пурпурный
    ((255, 0, 255), "magenta"),
    ((199, 21, 133), "medium violet red"),
    ((219, 112, 147), "pale violet red"),
    ((255, 20, 147), "deep pink"),
    ((255, 105, 180), "hot pink"),
    ((255, 192, 203), "pink"),
    ((255, 182, 193), "light pink"),
    ((255, 0, 255), "fuchsia"),
    ((221, 160, 221), "plum"),

    # Коричневый
    ((205, 127, 50), "bronze"),

    # Специальные металлы
    ((201, 166, 107), "brass"),
    ((184, 115, 51), "copper"),
    ((192, 192, 192), "silver"),
    ((128, 128, 128), "gray"),
    ((119, 136, 153), "light slate gray"),
    ((105, 105, 105), "dim gray"),

    # Тёмные материалы
    ((62, 39, 35), "espresso"),
    ((44, 62, 80), "charcoal blue"),
    ((93, 64, 55), "dark brown"),
    ((0, 77, 64), "dark green"),
]

# Серые оттенки (по значению value)
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


def sanitize_prompt_text(text: str, max_length: int = 50) -> str:
    """Очищает пользовательскую строку для безопасной вставки в промпт.
    Оставляет только буквы, цифры, пробелы и дефис; обрезает по длине."""
    if not text:
        return "object"
    cleaned = re.sub(r"[^\w\s-]", "", text, flags=re.UNICODE).strip()
    cleaned = cleaned[:max_length]
    return cleaned or "object"


def mask_iou(mask_a: np.ndarray, mask_b: np.ndarray) -> float:
    """Compute Intersection over Union between two binary masks."""
    intersection = np.logical_and(mask_a, mask_b).sum()
    union = np.logical_or(mask_a, mask_b).sum()
    if union == 0:
        return 0.0
    return float(intersection / union)


def get_color_hex_name(hex_color: int) -> str:
    """Конвертирует HEX-цвет в точное читаемое английское название для промпта.
    Использует lookup 50+ цветов CSS4/X11 с поиском ближайшего в RGB-пространстве."""
    r = (hex_color >> 16) & 0xFF
    g = (hex_color >> 8) & 0xFF
    b = hex_color & 0xFF
    mx = max(r, g, b)
    mn = min(r, g, b)
    sat = 0.0 if mx == 0 else (mx - mn) / mx
    val = mx / 255.0

    # Специальные светло-серые цвета металлов (проверяем первыми,
    # даже если цвет почти серый, чтобы нержавейка/титан не терялись в «white/gray»)
    metal_grays = {
        (232, 236, 239): "stainless_steel",
        (224, 224, 224): "silver",
        (110, 116, 120): "titanium",
    }
    best_metal_dist = float('inf')
    best_metal_name = None
    for (mr, mg, mb), name in metal_grays.items():
        dist = (r - mr) ** 2 + (g - mg) ** 2 + (b - mb) ** 2
        if dist < best_metal_dist:
            best_metal_dist = dist
            best_metal_name = name
    if best_metal_dist < 500:
        return best_metal_name

    # Серые оттенки (низкая насыщенность)
    if sat < 0.12:
        for threshold, name in _GRAY_COLORS:
            if val >= threshold:
                return name
        return "black"

    # Для очень тёмных насыщенных цветов проверяем специальные тёмные материалы
    if val < 0.18:
        dark_material_colors = {
            (62, 39, 35): "espresso",
            (44, 62, 80): "charcoal blue",
            (93, 64, 55): "dark brown",
            (0, 77, 64): "dark green",
            (28, 28, 28): "black",
        }
        best_name = None
        best_dist = float('inf')
        for (dr, dg, db), name in dark_material_colors.items():
            dist = (r - dr) ** 2 + (g - dg) ** 2 + (b - db) ** 2
            if dist < best_dist:
                best_dist = dist
                best_name = name
        if best_dist < 2500:
            return best_name

    # Специальные светло-серые цвета металлов (проверяем до общего поиска)
    metal_grays = {
        (232, 236, 239): "stainless_steel",
        (224, 224, 224): "silver",
        (110, 116, 120): "titanium",
    }
    best_metal_dist = float('inf')
    best_metal_name = None
    for (mr, mg, mb), name in metal_grays.items():
        dist = (r - mr) ** 2 + (g - mg) ** 2 + (b - mb) ** 2
        if dist < best_metal_dist:
            best_metal_dist = dist
            best_metal_name = name
    if best_metal_dist < 2500:
        return best_metal_name

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

    # Точные или очень близкие совпадения возвращаем как есть
    if best_dist < 2500:
        return best_name

    # Для далёких совпадений добавляем модификатор яркости
    if val < 0.30:
        return "very dark " + best_name
    elif val < 0.45:
        return "dark " + best_name
    elif val > 0.80:
        return "bright " + best_name
    return best_name
