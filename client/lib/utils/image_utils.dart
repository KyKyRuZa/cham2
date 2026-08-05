import 'dart:typed_data';
import 'package:image/image.dart' as img;

Uint8List normalizeImageBytes(Uint8List bytes) {
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;

    final oriented = img.bakeOrientation(decoded);
    return Uint8List.fromList(img.encodeJpg(oriented, quality: 100));
  } catch (e) {
    return bytes;
  }
}

/// Upscales [resultBytes] to match the dimensions of [originalBytes]
/// using cubic interpolation for smooth scaling.
Uint8List upscaleToOriginalResolution({
  required Uint8List resultBytes,
  required Uint8List originalBytes,
}) {
  final original = img.decodeImage(originalBytes);
  if (original == null) return resultBytes;
  final result = img.decodeImage(resultBytes);
  if (result == null) return resultBytes;
  final upscaled = img.copyResize(
    result,
    width: original.width,
    height: original.height,
    interpolation: img.Interpolation.cubic,
  );
  return Uint8List.fromList(img.encodeJpg(upscaled, quality: 100));
}

/// Entry point for `compute` — runs [upscaleToOriginalResolution] off the UI thread.
Uint8List upscaleToOriginalResolutionIsolate((Uint8List, Uint8List) args) {
  final (resultBytes, originalBytes) = args;
  return upscaleToOriginalResolution(
    resultBytes: resultBytes,
    originalBytes: originalBytes,
  );
}

