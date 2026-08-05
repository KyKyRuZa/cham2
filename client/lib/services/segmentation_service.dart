import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image/image.dart' as img;

class SegmentationService {
  static const int defaultRequestTimeout = 90;
  final String serverUrl;
  final String? apiKey;
  final http.Client _client;

  SegmentationService({String? serverUrl, String? apiKey, http.Client? client})
    : serverUrl = serverUrl ?? _resolveServerUrl(),
      apiKey = apiKey ?? _resolveApiKey(),
      _client = client ?? http.Client();

  /// Определяет URL сервера с приоритетом:
  /// 1. --dart-define (SERVER_URL) 2. .env (SERVER_URL) 3. значение по умолчанию.
  static String _resolveServerUrl() {
    // --dart-define имеет наивысший приоритет (используется в релизных сборках/CI)
    const defineUrl = String.fromEnvironment('SERVER_URL', defaultValue: '');
    if (defineUrl.isNotEmpty) {
      return defineUrl;
    }
    // Значение из .env, если файл загружен и ключ задан
    final envUrl = dotenv.isInitialized ? dotenv.maybeGet('SERVER_URL') : null;
    if (envUrl != null && envUrl.isNotEmpty) {
      return envUrl;
    }
    return 'http://87.228.10.101';
  }

  /// Определяет API-ключ с приоритетом: --dart-define (API_KEY) -> .env (API_KEY).
  static String? _resolveApiKey() {
    // --dart-define имеет наивысший приоритет (используется в релизных сборках/CI)
    const defineKey = String.fromEnvironment('API_KEY', defaultValue: '');
    if (defineKey.isNotEmpty) {
      return defineKey;
    }
    final envKey = dotenv.isInitialized ? dotenv.maybeGet('API_KEY') : null;
    if (envKey != null && envKey.isNotEmpty) {
      return envKey;
    }
    return null;
  }

  static (Uint8List, double, double) _compressImage(
    Uint8List bytes, {
    int maxDim = 1024,
    int quality = 80,
  }) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return (bytes, 1.0, 1.0);
      final int origW = decoded.width;
      final int origH = decoded.height;
      if (origW > maxDim || origH > maxDim) {
        final double scale = maxDim / math.max(origW, origH);
        final int w = origW > origH ? maxDim : (origW * scale).round();
        final int h = origW > origH ? (origH * scale).round() : maxDim;
        final resized = img.copyResize(decoded, width: w, height: h);
        return (Uint8List.fromList(img.encodeJpg(resized, quality: quality)), scale, scale);
      }
      return (Uint8List.fromList(img.encodeJpg(decoded, quality: quality)), 1.0, 1.0);
    } on Exception catch (_) {
      return (bytes, 1.0, 1.0);
    }
  }

  Future<bool> isServerAvailable() async {
    try {
      final response = await _client
          .get(Uri.parse('$serverUrl/health'))
          .timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<Uint8List?> segmentObject({
    required Uint8List imageBytes,
    required Offset imagePosition,
    required int imageWidth,
    required int imageHeight,
    double? widgetWidth,
    double? widgetHeight,
    required String material,
    required int colorHex,
    String? colorName,
    String objectName = 'object',
    double strength = 1.0,
    double guidanceScale = 5.0,
    int numInferenceSteps = 30,
    bool patina = false,
    bool fromPipette = false,
  }) async {
    try {
      final int rgbValue = colorHex & 0xFFFFFF;
      final int colorR = (rgbValue >> 16) & 0xFF;
      final int colorG = (rgbValue >> 8) & 0xFF;
      final int colorB = rgbValue & 0xFF;

      // imagePosition передаётся в пикселях исходного изображения;
      // ниже масштабируем его под сжатую копию, которую отправляем на сервер.

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$serverUrl/ai-recolor'),
      );
      // Передаём API-ключ, если он задан
      if (apiKey != null && apiKey!.isNotEmpty) {
        request.headers['X-API-Key'] = apiKey!;
      }
      final (compressedImage, scaleX, scaleY) = _compressImage(imageBytes);
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          compressedImage,
          filename: 'image.jpg',
          contentType: MediaType('image', 'jpeg'),
        ),
      );
      request.fields['point_x'] = (imagePosition.dx * scaleX).round().toString();
      request.fields['point_y'] = (imagePosition.dy * scaleY).round().toString();
      request.fields['material'] = material;
      request.fields['patina'] = patina ? 'true' : 'false';
      request.fields['color_hex'] =
          '0x${rgbValue.toRadixString(16).padLeft(6, '0')}';
      request.fields['color_r'] = colorR.toString();
      request.fields['color_g'] = colorG.toString();
      request.fields['color_b'] = colorB.toString();
      request.fields['from_pipette'] = fromPipette ? 'true' : 'false';
      if (colorName != null) {
        request.fields['color_name'] = colorName;
      }
      request.fields['object_name'] = objectName;
      request.fields['strength'] = strength.toString();
      request.fields['guidance_scale'] = guidanceScale.toString();
      request.fields['num_inference_steps'] = numInferenceSteps.toString();

      final streamedResponse = await request.send().timeout(
        Duration(
          seconds: int.fromEnvironment(
            'REQUEST_TIMEOUT',
            defaultValue: defaultRequestTimeout,
          ),
        ),
      );
      final sw = Stopwatch()..start();
      final response = await http.Response.fromStream(streamedResponse);
      sw.stop();
      if (kDebugMode) {
        debugPrint(
          'AI recolor response: status=${response.statusCode}, bytes=${response.bodyBytes.length}',
        );
      }

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        return Uint8List.fromList(response.bodyBytes);
      }
      if (kDebugMode) {
        debugPrint(
          'AI recolor empty/invalid response: status=${response.statusCode}',
        );
      }
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('AI recolor error: $e');
      return null;
    }
  }

  void dispose() {
    _client.close();
  }
}
