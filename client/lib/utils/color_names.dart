import 'package:flutter/material.dart';

/// Расширенная таблица цветов (hex -> английское имя) для подбора
/// ближайшего названия при работе с пипеткой. НЕ используется в палитре
/// (color_palette_screen.dart) — только для преобразования захваченного
/// пипеткой RGB в понятное FLUX.2 словесное имя.
///
/// Источник: расширенный набор CSS4/X11 + популярные оттенки.
const List<NamedColor> kExtendedNamedColors = [
  // ---- Красный ----
  NamedColor(0xFFFF0000, 'red'),
  NamedColor(0xFFB22222, 'firebrick'),
  NamedColor(0xFF8B0000, 'dark red'),
  NamedColor(0xFF800000, 'maroon'),
  NamedColor(0xFFDC143C, 'crimson'),
  NamedColor(0xFFF08080, 'light coral'),
  NamedColor(0xFFFA8072, 'salmon'),
  NamedColor(0xFFFF4500, 'orange red'),
  NamedColor(0xFFCD5C5C, 'indian red'),
  NamedColor(0xFFE9967A, 'dark salmon'),
  // ---- Оранжевый / персиковый ----
  NamedColor(0xFFFFA500, 'orange'),
  NamedColor(0xFFFF8C00, 'dark orange'),
  NamedColor(0xFFFF7F50, 'coral'),
  NamedColor(0xFFFFDAB9, 'peach puff'),
  NamedColor(0xFFFFE4C4, 'bisque'),
  NamedColor(0xFFD2691E, 'chocolate'),
  NamedColor(0xFFA0522D, 'sienna'),
  NamedColor(0xFFDEB887, 'burlywood'),
  NamedColor(0xFFF4A460, 'sandy brown'),
  NamedColor(0xFFDA70D6, 'orchid'),
  // ---- Жёлтый / золотой ----
  NamedColor(0xFFFFFF00, 'yellow'),
  NamedColor(0xFFFFD700, 'gold'),
  NamedColor(0xFFDAA520, 'goldenrod'),
  NamedColor(0xFFB8860B, 'dark goldenrod'),
  NamedColor(0xFFF0E68C, 'khaki'),
  NamedColor(0xFFEEE8AA, 'pale goldenrod'),
  NamedColor(0xFFFFFACD, 'lemon chiffon'),
  NamedColor(0xFFFFF8DC, 'cornsilk'),
  NamedColor(0xFFF5DEB3, 'wheat'),
  NamedColor(0xFFFFEF96, 'papaya whip'),
  // ---- Зелёный ----
  NamedColor(0xFF008000, 'green'),
  NamedColor(0xFF006400, 'dark green'),
  NamedColor(0xFF228B22, 'forest green'),
  NamedColor(0xFF2E8B57, 'sea green'),
  NamedColor(0xFF3CB371, 'medium sea green'),
  NamedColor(0xFF00FF00, 'lime'),
  NamedColor(0xFF32CD32, 'lime green'),
  NamedColor(0xFF90EE90, 'light green'),
  NamedColor(0xFF9ACD32, 'yellow green'),
  NamedColor(0xFF6B8E23, 'olive green'),
  NamedColor(0xFF808000, 'olive'),
  NamedColor(0xFF556B2F, 'dark olive green'),
  NamedColor(0xFF7CFC00, 'lawn green'),
  NamedColor(0xFFADFF2F, 'green yellow'),
  NamedColor(0xFF00FA9A, 'medium spring green'),
  NamedColor(0xFF66CDAA, 'medium aquamarine'),
  // ---- Бирюзовый / циан ----
  NamedColor(0xFF00FFFF, 'cyan'),
  NamedColor(0xFFE0FFFF, 'light cyan'),
  NamedColor(0xFF40E0D0, 'turquoise'),
  NamedColor(0xFF48D1CC, 'medium turquoise'),
  NamedColor(0xFF20B2AA, 'light sea green'),
  NamedColor(0xFF008B8B, 'dark cyan'),
  NamedColor(0xFF008080, 'teal'),
  NamedColor(0xFF5F9EA0, 'cadet blue'),
  NamedColor(0xFF7FFFD4, 'aquamarine'),
  NamedColor(0xFFAFEEEE, 'pale turquoise'),
  // ---- Синий ----
  NamedColor(0xFF0000FF, 'blue'),
  NamedColor(0xFF00008B, 'dark blue'),
  NamedColor(0xFF000080, 'navy'),
  NamedColor(0xFF191970, 'midnight blue'),
  NamedColor(0xFF4169E1, 'royal blue'),
  NamedColor(0xFF1E90FF, 'dodger blue'),
  NamedColor(0xFF6495ED, 'cornflower blue'),
  NamedColor(0xFF87CEEB, 'sky blue'),
  NamedColor(0xFF87CEFA, 'light sky blue'),
  NamedColor(0xFFB0C4DE, 'light steel blue'),
  NamedColor(0xFF4682B4, 'steel blue'),
  NamedColor(0xFF70A1FF, 'azure'),
  NamedColor(0xFF00BFFF, 'deep sky blue'),
  NamedColor(0xFF1E6FFF, 'azure blue'),
  // ---- Фиолетовый / пурпурный ----
  NamedColor(0xFF800080, 'purple'),
  NamedColor(0xFF4B0082, 'indigo'),
  NamedColor(0xFF483D8B, 'dark slate blue'),
  NamedColor(0xFF6A5ACD, 'slate blue'),
  NamedColor(0xFF7B68EE, 'medium slate blue'),
  NamedColor(0xFF8A2BE2, 'blue violet'),
  NamedColor(0xFF9400D3, 'dark violet'),
  NamedColor(0xFF9932CC, 'dark orchid'),
  NamedColor(0xFFBA55D3, 'medium orchid'),
  NamedColor(0xFFDA70D6, 'orchid'),
  NamedColor(0xFFEE82EE, 'violet'),
  NamedColor(0xFFD8BFD8, 'thistle'),
  NamedColor(0xFFE6E6FA, 'lavender'),
  NamedColor(0xFFC8A2C8, 'lilac'),
  // ---- Розовый / маджента ----
  NamedColor(0xFFFF00FF, 'magenta'),
  NamedColor(0xFFFF1493, 'deep pink'),
  NamedColor(0xFFFF69B4, 'hot pink'),
  NamedColor(0xFFFFC0CB, 'pink'),
  NamedColor(0xFFFFB6C1, 'light pink'),
  NamedColor(0xFFDB7093, 'pale violet red'),
  NamedColor(0xFFC71585, 'medium violet red'),
  NamedColor(0xFFFFC0CB, 'rose'),
  NamedColor(0xFFF4C2C2, 'pinkish'),
  // ---- Коричневый / земляной ----
  NamedColor(0xFFA52A2A, 'brown'),
  NamedColor(0xFF8B4513, 'saddle brown'),
  NamedColor(0xFFA0522D, 'sienna'),
  NamedColor(0xFFD2691E, 'bronze'),
  NamedColor(0xFFCD853F, 'peru'),
  NamedColor(0xFFB5651D, 'dark bronze'),
  NamedColor(0xFFEED6AF, 'blanched almond'),
  NamedColor(0xFFC19A6B, 'camel'),
  NamedColor(0xFF7B3F00, 'dark brown'),
  NamedColor(0xFF5C3A21, 'espresso'),
  NamedColor(0xFF9B7653, 'taupe'),
  NamedColor(0xFF704214, 'dark oak'),
  // ---- Серый / металлы ----
  NamedColor(0xFF808080, 'gray'),
  NamedColor(0xFFA9A9A9, 'dark gray'),
  NamedColor(0xFFD3D3D3, 'light gray'),
  NamedColor(0xFF696969, 'dim gray'),
  NamedColor(0xFFC0C0C0, 'silver'),
  NamedColor(0xFFE0E0E0, 'light silver'),
  NamedColor(0xFFF5F5F5, 'white smoke'),
  NamedColor(0xFFFAFAFA, 'off white'),
  NamedColor(0xFFFFFFFF, 'white'),
  NamedColor(0xFF000000, 'black'),
  NamedColor(0xFF1A1A1A, 'rich black'),
  NamedColor(0xFF2F2F2F, 'charcoal'),
  NamedColor(0xFF3A3A3A, 'dark charcoal'),
  NamedColor(0xFF464646, 'graphite'),
  NamedColor(0xFF6E7478, 'titanium'),
  NamedColor(0xFFB0BEC5, 'blue gray'),
  NamedColor(0xFF78909C, 'blue grey'),
  NamedColor(0xFF455A64, 'blueish gray'),
  NamedColor(0xFFCD7F32, 'copper'),
  NamedColor(0xFFC9A66B, 'brass'),
  NamedColor(0xFFE8ECEF, 'stainless steel'),
  NamedColor(0xFFD4AF37, 'metallic gold'),
  NamedColor(0xFFB87333, 'metallic copper'),
];

class NamedColor {
  final int hex;
  final String name;
  const NamedColor(this.hex, this.name);
}

/// Возвращает ближайшее словесное имя цвета (по евклидову расстоянию в RGB)
/// для захваченного пипеткой цвета. Если цвет почти серый — подбирает
/// соответствующий серый/металлический оттенок, иначе — ближайший цветной.
String nearestColorName(Color color) {
  final int r = (color.r * 255.0).round().clamp(0, 255);
  final int g = (color.g * 255.0).round().clamp(0, 255);
  final int b = (color.b * 255.0).round().clamp(0, 255);

  // Всегда ищем ближайший цвет по евклидову расстоянию в RGB по ВСЕЙ
  // таблице (в ней уже есть серые, белые, чёрные и металлические оттенки).
  // Отдельную «серую» ветку не делаем: бледно-розовый/бледно-голубой при
  // низкой насыщенности иначе ошибочно попадал в «gray».
  int bestDist = 1 << 30;
  String bestName = kExtendedNamedColors.first.name;
  for (final named in kExtendedNamedColors) {
    final int cr = (named.hex >> 16) & 0xFF;
    final int cg = (named.hex >> 8) & 0xFF;
    final int cb = named.hex & 0xFF;
    final int dr = r - cr;
    final int dg = g - cg;
    final int db = b - cb;
    final int dist = dr * dr + dg * dg + db * db;
    if (dist < bestDist) {
      bestDist = dist;
      bestName = named.name;
    }
  }
  return bestName;
}
