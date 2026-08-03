import 'dart:typed_data';
import 'package:image/image.dart' as img;

Uint8List normalizeImageBytes(Uint8List bytes) {
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;

    final oriented = img.bakeOrientation(decoded);
    return Uint8List.fromList(img.encodeJpg(oriented));
  } catch (e) {
    return bytes;
  }
}
