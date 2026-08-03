import 'dart:typed_data';
import 'dart:math' as math;
import 'package:image/image.dart' as img;
import '../utils/logger.dart';

/// Service for realistic image recoloring using HSV color space
/// This algorithm preserves texture, shadows, highlights, and material factors
class ImageProcessingService {
  static const double darkThreshold =
      0.35;
  static const double brightThreshold =
      0.75;

  static Uint8List recolorImage({
    required Uint8List imageBytes,
    required int width,
    required int height,
    required Uint8List selectionMask,
    required int targetRed,
    required int targetGreen,
    required int targetBlue,
    double blendFactor = 1.0,
    Uint8List? woodTextureBytes,
  }) {
    final image = img.decodeImage(imageBytes);
    if (image == null) return imageBytes;

    if (selectionMask.length != image.width * image.height) {
      return imageBytes;
    }

    img.Image? textureImg;
    if (woodTextureBytes != null) {
      final decodedTexture = img.decodeImage(woodTextureBytes);
      if (decodedTexture != null) {
        textureImg = img.copyResize(
          decodedTexture,
          width: width,
          height: height,
        );
      }
    }

    int darkCount = 0;
    int brightCount = 0;
    int midCount = 0;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final index = y * image.width + x;

        if (selectionMask[index] == 1) {
          final pixel = image.getPixel(x, y);
          final originalR = pixel.r.toInt();
          final originalG = pixel.g.toInt();
          final originalB = pixel.b.toInt();

          final originalHsv = _rgbToHsv(originalR, originalG, originalB);
          final value = originalHsv[2];

          final isDark = value < darkThreshold;
          final isBright = value > brightThreshold;

          if ((x + y * width) % 1000 == 0) {
            _logPixelClassification(
              x,
              y,
              originalR,
              originalG,
              originalB,
              value,
              isDark,
              isBright,
            );
          }

          if (isDark) {
            darkCount++;
          } else if (isBright) {
            brightCount++;
          } else {
            midCount++;
          }

          final gray =
              (0.299 * originalR + 0.587 * originalG + 0.114 * originalB)
                  .round();

          int finalR, finalG, finalB;

          if (isDark) {
            finalR = _recolorDarkPixelWithScreen(
              originalR,
              targetRed,
              gray,
              blendFactor,
            );
            finalG = _recolorDarkPixelWithScreen(
              originalG,
              targetGreen,
              gray,
              blendFactor,
            );
            finalB = _recolorDarkPixelWithScreen(
              originalB,
              targetBlue,
              gray,
              blendFactor,
            );
          } else if (isBright) {
            finalR = _recolorWithOverlay(originalR, targetRed, blendFactor);
            finalG = _recolorWithOverlay(originalG, targetGreen, blendFactor);
            finalB = _recolorWithOverlay(originalB, targetBlue, blendFactor);
          } else {
            var blendedR = (gray * targetRed) ~/ 255;
            var blendedG = (gray * targetGreen) ~/ 255;
            var blendedB = (gray * targetBlue) ~/ 255;
            if (blendFactor < 1.0) {
              finalR =
                  originalR + ((blendedR - originalR) * blendFactor).round();
              finalG =
                  originalG + ((blendedG - originalG) * blendFactor).round();
              finalB =
                  originalB + ((blendedB - originalB) * blendFactor).round();
            } else {
              finalR = blendedR;
              finalG = blendedG;
              finalB = blendedB;
            }
          }

          if (textureImg != null) {
            final texPixel = textureImg.getPixel(x, y);
            final texR = texPixel.r.toInt();
            final texG = texPixel.g.toInt();
            final texB = texPixel.b.toInt();
            final texLum = (0.299 * texR + 0.587 * texG + 0.114 * texB) / 255.0;

            double baseR = finalR / 255.0;
            double baseG = finalG / 255.0;
            double baseB = finalB / 255.0;

            double overlay(double base, double blend) {
              if (base < 0.5) {
                return 2 * base * blend;
              } else {
                return 1 - 2 * (1 - base) * (1 - blend);
              }
            }

            final resultR = (overlay(baseR, texLum) * 255).round().clamp(
              0,
              255,
            );
            final resultG = (overlay(baseG, texLum) * 255).round().clamp(
              0,
              255,
            );
            final resultB = (overlay(baseB, texLum) * 255).round().clamp(
              0,
              255,
            );

            image.setPixelRgb(x, y, resultR, resultG, resultB);
          } else {
            image.setPixelRgb(
              x,
              y,
              finalR.clamp(0, 255),
              finalG.clamp(0, 255),
              finalB.clamp(0, 255),
            );
          }
        }
      }
    }

    _logRecolorSummary(
      darkCount,
      brightCount,
      midCount,
      targetRed,
      targetGreen,
      targetBlue,
    );

    return Uint8List.fromList(img.encodePng(image));
  }

  static Uint8List filterMaskByColorTolerance({
    required Uint8List imageBytes,
    required int width,
    required int height,
    required Uint8List currentMask,
    required int avgR,
    required int avgG,
    required int avgB,
    required int tolerance,
  }) {
    final image = img.decodeImage(imageBytes);
    if (image == null) return currentMask;

    if (currentMask.length != width * height) {
      return currentMask;
    }

    final filteredMask = Uint8List.fromList(currentMask);
    int removedCount = 0;
    int totalSelected = 0;

    final toleranceSq = tolerance * tolerance;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final idx = y * width + x;

        if (currentMask[idx] == 1) {
          totalSelected++;
          final pixel = image.getPixel(x, y);
          final r = pixel.r.toInt();
          final g = pixel.g.toInt();
          final b = pixel.b.toInt();

          final dr = r - avgR;
          final dg = g - avgG;
          final db = b - avgB;
          final distanceSq = dr * dr + dg * dg + db * db;

          if (distanceSq > toleranceSq) {
            filteredMask[idx] = 0;
            removedCount++;
          }
        }
      }
    }

    AppLog.i('\n=== COLOR FILTERING ===', 'Filter');
    AppLog.i('Average color: RGB($avgR,$avgG,$avgB)', 'Filter');
    AppLog.i('Tolerance: $tolerance', 'Filter');
    AppLog.i('Total selected: $totalSelected', 'Filter');
    AppLog.i('Pixels removed: $removedCount', 'Filter');
    AppLog.i('Remaining: ${totalSelected - removedCount}', 'Filter');
    AppLog.i('========================\n', 'Filter');

    return filteredMask;
  }

  static int _recolorDarkPixelWithScreen(
    int original,
    int target,
    int gray,
    double blendFactor,
  ) {
    var result = original + target - (original * target) ~/ 255;

    final luminanceFactor = 0.3 + 0.7 * (gray / 255.0);
    result = (result * luminanceFactor).round();

    result = original + ((result - original) * blendFactor).round();

    return result.clamp(0, 255);
  }

  static int _recolorWithOverlay(int original, int target, double blendFactor) {
    int result;
    if (original < 128) {
      result = (2 * original * target) ~/ 255;
    } else {
      result = 2 * original + 2 * target - (2 * original * target) ~/ 255 - 255;
    }

    result = original + ((result - original) * blendFactor).round();
    return result.clamp(0, 255);
  }

  static void _logPixelClassification(
    int x,
    int y,
    int r,
    int g,
    int b,
    double value,
    bool isDark,
    bool isBright,
  ) {
    final colorName = _getColorName(r, g, b);
    final brightness = isDark ? 'ТЁМНЫЙ' : (isBright ? 'ЯРКИЙ' : 'СРЕДНИЙ');
    AppLog.d('[PixelClassify] x=$x y=$y RGB=($r,$g,$b) Value=${(value * 100).toInt()}% [$brightness] $colorName', 'PixelClassify');
  }

  static void _logRecolorSummary(
    int darkCount,
    int brightCount,
    int midCount,
    int r,
    int g,
    int b,
  ) {
    final total = darkCount + brightCount + midCount;
    if (total == 0) return;

    final darkPct = (darkCount * 100 / total).toInt();
    final brightPct = (brightCount * 100 / total).toInt();
    final midPct = (midCount * 100 / total).toInt();

    AppLog.i('\n=== RECOLOR SUMMARY ===', 'Recolor');
    AppLog.i('Target color: RGB($r,$g,$b)', 'Recolor');
    AppLog.i('Total selected pixels: $total', 'Recolor');
    AppLog.i('Dark pixels (<35% brightness): $darkCount ($darkPct%) -> dark strategy', 'Recolor');
    AppLog.i('Bright pixels (>75% brightness): $brightCount ($brightPct%) -> overlay strategy', 'Recolor');
    AppLog.i('Medium pixels: $midCount ($midPct%) -> standard blend', 'Recolor');
    AppLog.i('========================\n', 'Recolor');
  }

  static String _getColorName(int r, int g, int b) {
    if (r < 50 && g < 50 && b < 50) return '(black)';
    if (r > 200 && g > 200 && b > 200) return '(white)';
    if (r > g && r > b) return '(reddish)';
    if (g > r && g > b) return '(greenish)';
    if (b > r && b > g) return '(bluish)';
    if (r > 150 && g > 150 && b < 100) return '(yellowish)';
    if (r > 150 && b > 150 && g < 100) return '(magenta)';
    if (g > 150 && b > 150 && r < 100) return '(cyan)';
    return '';
  }

  static List<double> rgbToHsv(int r, int g, int b) {
    return _rgbToHsv(r, g, b);
  }

  static List<double> _rgbToHsv(int r, int g, int b) {
    final rNorm = r / 255.0;
    final gNorm = g / 255.0;
    final bNorm = b / 255.0;

    final max = math.max(rNorm, math.max(gNorm, bNorm));
    final min = math.min(rNorm, math.min(gNorm, bNorm));
    final diff = max - min;

    final value = max;
    final saturation = max == 0 ? 0.0 : diff / max;

    double hue = 0;
    if (diff != 0) {
      if (max == rNorm) {
        hue = 60 * (((gNorm - bNorm) / diff) % 6);
      } else if (max == gNorm) {
        hue = 60 * ((bNorm - rNorm) / diff + 2);
      } else {
        hue = 60 * ((rNorm - gNorm) / diff + 4);
      }
    }
    if (hue < 0) hue += 360;

    return [hue, saturation, value];
  }
}
