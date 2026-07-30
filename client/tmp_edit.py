
import sys
path = r"C:\scr\osnovaaaaa\client\lib\screens\color_palette_screen.dart"
with open(path, "r", encoding="utf-8") as f:
    content = f.read()

old = """    _ColorCategory("Фиолетовый", [
      const Color(0xFF9C27B0),
      const Color(0xFF4A148C),
      const Color(0xFFCE93D8),
      const Color(0xFFAB47BC),
      const Color(0xFF7B1FA2),
    ]),
    _ColorCategory("Коричневый", ["""

new = """    _ColorCategory("Фиолетовый", [
      const Color(0xFF9C27B0),
      const Color(0xFF4A148C),
      const Color(0xFFCE93D8),
      const Color(0xFFAB47BC),
      const Color(0xFF7B1FA2),
    ]),
    _ColorCategory("Голубой", [
      const Color(0xFF3F51B5),
      const Color(0xFF1A237E),
      const Color(0xFF9FA8DA),
      const Color(0xFF3949AB),
      const Color(0xFF283593),
    ]),
    _ColorCategory("Коричневый", ["""

if old in content:
    content = content.replace(old, new, 1)
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
    print("SUCCESS")
else:
    print("NOT FOUND")

