import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import '../models/selection_tool.dart';

class SelectionCanvas extends StatefulWidget {
  final Uint8List imageBytes;
  final Uint8List selectionMask;
  final SelectionTool currentTool;
  final double brushSize;
  final List<Offset> lassoPoints;
  final List<List<int>> polygonPoints;
  final List<Offset> rectanglePoints;
  final List<Offset> boundaryPoints;
  final Function(Offset)? onBoundaryPoint;
  final VoidCallback? onBoundaryStart;
  final VoidCallback? onBoundaryEnd;
  final Function(Uint8List) onSelectionUpdate;
  final Function(List<Offset>) onLassoPointsUpdate;
  final Function(List<List<int>>) onPolygonPointsUpdate;
  final Function(List<Offset>) onRectanglePointsUpdate;
  final VoidCallback? onDrawingStart;
  final VoidCallback? onDrawingEnd;
  final Future<void> Function(
    Uint8List orientedBytes,
    Offset imagePosition,
    int imageWidth,
    int imageHeight,
  )?
  onAutoSegmentTap;
  final VoidCallback? onAutoSegmentComplete = null;
  final void Function(
    Uint8List orientedBytes,
    Offset imagePosition,
    int imageWidth,
    int imageHeight,
    Color pickedColor,
  )?
  onPickColorTap;
  final Uint8List? previewImage;
  final bool isSegmentationModeActive;

  const SelectionCanvas({
    super.key,
    required this.imageBytes,
    this.previewImage,
    required this.selectionMask,
    required this.currentTool,
    required this.brushSize,
    required this.lassoPoints,
    required this.polygonPoints,
    this.rectanglePoints = const [],
    this.boundaryPoints = const [],
    this.onBoundaryPoint,
    this.onBoundaryStart,
    this.onBoundaryEnd,
    required this.onSelectionUpdate,
    required this.onLassoPointsUpdate,
    required this.onPolygonPointsUpdate,
    required this.onRectanglePointsUpdate,
    this.onDrawingStart,
    this.onDrawingEnd,
    this.onAutoSegmentTap,
    this.onPickColorTap,
    this.isSegmentationModeActive = false,
  });

  @override
  State<SelectionCanvas> createState() => _SelectionCanvasState();
}

class _SelectionCanvasState extends State<SelectionCanvas>
    with TickerProviderStateMixin {
  ui.Image? _decodedImage;
  Size _imageSize = const Size(800, 600);
  Uint8List? _orientedImageBytes;
  ui.Image? _previewDecodedImage;
  ByteData? _decodedImageRgba;

  double _currentScale = 1.0;
  double _targetScale = 1.0;
  Offset _currentOffset = Offset.zero;
  Offset _targetOffset = Offset.zero;
  Offset? _lastFocalPoint;
  double? _lastScale;
  int _currentPointerCount = 0;
  bool _isZooming = false;
  bool _isPanning = false;

  // Guard against tap spam
  late AnimationController _selectionMaskController;

  @override
  void initState() {
    super.initState();
    _loadImage();
    _selectionMaskController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _startSmoothZoomTicker();
  }

  @override
  void didUpdateWidget(SelectionCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.imageBytes != oldWidget.imageBytes) {
      _loadImage();
    }
    if (widget.previewImage != oldWidget.previewImage) {
      _loadPreviewImage();
    }
    if (widget.selectionMask != oldWidget.selectionMask &&
        widget.selectionMask.any((m) => m == 1)) {
      _selectionMaskController.forward(from: 0);
    }
    if (widget.currentTool != oldWidget.currentTool &&
        widget.currentTool != SelectionTool.eyedropper) {
      _decodedImageRgba = null;
    }
  }

  Future<void> _loadPreviewImage() async {
    if (widget.previewImage == null) {
      _previewDecodedImage = null;
      if (mounted) {
        setState(() {});
      }
      return;
    }
    try {
      final codec = await ui.instantiateImageCodec(widget.previewImage!);
      final frame = await codec.getNextFrame();
      if (mounted) {
        setState(() {
          _previewDecodedImage = frame.image;
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading preview image: $e');
      _previewDecodedImage = null;
    }
  }

  void _startSmoothZoomTicker() {
    createTicker((elapsed) {
      final scaleDiff = _targetScale - _currentScale;
      final offsetDiff = _targetOffset - _currentOffset;

      if (scaleDiff.abs() > 0.0001 || offsetDiff.distance > 0.01) {
        setState(() {
          _currentScale += scaleDiff * 0.15;
          _currentOffset += offsetDiff * 0.15;
        });
      } else if (_targetOffset != _currentOffset ||
          _targetScale != _currentScale) {
        setState(() {
          _currentScale = _targetScale;
          _currentOffset = _targetOffset;
        });
      }
    }).start();
  }

  @override
  void dispose() {
    _selectionMaskController.dispose();
    super.dispose();
  }

  Future<void> _loadImage() async {
    try {
      // Decode with EXIF orientation handling to get correct dimensions
      final img.Image? decodedImg = img.decodeImage(widget.imageBytes);
      if (decodedImg != null) {
        // Apply EXIF orientation (bakes rotation into the image data)
        final img.Image orientedImg = img.bakeOrientation(decodedImg);
        // Get dimensions AFTER orientation is applied
        _imageSize = Size(
          orientedImg.width.toDouble(),
          orientedImg.height.toDouble(),
        );

        // Store oriented bytes to send to server (syncs with display)
        _orientedImageBytes = Uint8List.fromList(img.encodeJpg(orientedImg));

        // Encode back to PNG for display (lossless)
        final Uint8List orientedBytesPng = Uint8List.fromList(
          img.encodePng(orientedImg),
        );
        final codec = await ui.instantiateImageCodec(orientedBytesPng);
        final frame = await codec.getNextFrame();
        final rgba = await frame.image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        if (mounted) {
          setState(() {
            _decodedImage = frame.image;
            _decodedImageRgba = rgba;
          });
        }
        if (kDebugMode) {
          debugPrint(
            'Loaded image with EXIF orientation: ${_imageSize.width}x${_imageSize.height}',
          );
        }
      } else {
        // Fallback: use original bytes without EXIF handling
        _orientedImageBytes = widget.imageBytes;
        final codec = await ui.instantiateImageCodec(widget.imageBytes);
        final frame = await codec.getNextFrame();
        final rgba = await frame.image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        if (mounted) {
          setState(() {
            _decodedImage = frame.image;
            _decodedImageRgba = rgba;
            _imageSize = Size(
              frame.image.width.toDouble(),
              frame.image.height.toDouble(),
            );
          });
        }
        if (kDebugMode) {
          debugPrint(
            'Warning: Could not decode image for EXIF handling, using original: ${_imageSize.width}x${_imageSize.height}',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading image: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTapUp: (details) => _onTap(details.localPosition, constraints),
          onScaleStart: (details) => _onScaleStart(details),
          onScaleUpdate: (details) => _onScaleUpdate(details),
          onScaleEnd: (details) => _onScaleEnd(details),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(color: const Color(0xFF151412)),
              if (_decodedImage != null)
                CustomPaint(
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                  painter: _SelectionCanvasPainter(
                    image: _decodedImage,
                    previewImage: _previewDecodedImage,
                    selectionMask: widget.selectionMask,
                    imageSize: _imageSize,
                    currentScale: _currentScale,
                    currentOffset: _currentOffset,
                    isZooming: _isZooming,
                    isPanning: _isPanning,
                    maskAnimationValue: _selectionMaskController.value,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _onTap(Offset position, BoxConstraints constraints) {
    if (widget.currentTool == SelectionTool.interactiveSegmentation &&
        widget.isSegmentationModeActive &&
        widget.onAutoSegmentTap != null) {
      final imagePosition = _screenToImageCoordinates(position, constraints);
      final int imageWidth = _imageSize.width.toInt();
      final int imageHeight = _imageSize.height.toInt();
      final orientedBytes = _orientedImageBytes ?? widget.imageBytes;
      widget.onAutoSegmentTap!(
        orientedBytes,
        imagePosition,
        imageWidth,
        imageHeight,
      );
      return;
    }

    if (widget.currentTool == SelectionTool.eyedropper &&
        widget.onPickColorTap != null) {
      final imagePosition = _screenToImageCoordinates(position, constraints);
      final color = _pickColorAt(imagePosition);
      _decodedImageRgba = null;
      if (color != null) {
        final orientedBytes = _orientedImageBytes ?? widget.imageBytes;
        widget.onPickColorTap!(
          orientedBytes,
          imagePosition,
          _imageSize.width.toInt(),
          _imageSize.height.toInt(),
          color,
        );
      }
    }
  }

  /// Считывает цвет пикселя исходного (oriented) изображения по координате.
  Color? _pickColorAt(Offset imagePosition) {
    final rgba = _decodedImageRgba;
    if (rgba == null) return null;
    final int x = imagePosition.dx.round().clamp(
      0,
      _imageSize.width.toInt() - 1,
    );
    final int y = imagePosition.dy.round().clamp(
      0,
      _imageSize.height.toInt() - 1,
    );
    final int width = _imageSize.width.toInt();
    final int byteOffset = (y * width + x) * 4;
    if (byteOffset + 3 >= rgba.lengthInBytes) return null;
    final int r = rgba.getUint8(byteOffset);
    final int g = rgba.getUint8(byteOffset + 1);
    final int b = rgba.getUint8(byteOffset + 2);
    final int a = rgba.getUint8(byteOffset + 3);
    return Color.fromARGB(a, r, g, b);
  }

  Offset _screenToImageCoordinates(
    Offset screenPosition,
    BoxConstraints constraints,
  ) {
    final aspectRatio = _imageSize.width / _imageSize.height;
    double baseWidth, baseHeight;

    if (constraints.maxWidth / constraints.maxHeight > aspectRatio) {
      baseWidth = constraints.maxWidth;
      baseHeight = baseWidth / aspectRatio;
    } else {
      baseHeight = constraints.maxHeight;
      baseWidth = baseHeight * aspectRatio;
    }

    final centerX = constraints.maxWidth / 2;
    final centerY = constraints.maxHeight / 2;
    final baseOffsetX = centerX - baseWidth / 2;
    final baseOffsetY = centerY - baseHeight / 2;

    final srcWidth = _imageSize.width / _currentScale;
    final srcHeight = _imageSize.height / _currentScale;

    final pixelsPerImageX = srcWidth / baseWidth;
    final pixelsPerImageY = srcHeight / baseHeight;

    final srcX =
        ((_imageSize.width - srcWidth) / 2 -
                _currentOffset.dx * pixelsPerImageX)
            .clamp(0.0, _imageSize.width - srcWidth);
    final srcY =
        ((_imageSize.height - srcHeight) / 2 -
                _currentOffset.dy * pixelsPerImageY)
            .clamp(0.0, _imageSize.height - srcHeight);

    final scaleX = baseWidth / srcWidth;
    final scaleY = baseHeight / srcHeight;

    final imageX = (screenPosition.dx - baseOffsetX) / scaleX + srcX;
    final imageY = (screenPosition.dy - baseOffsetY) / scaleY + srcY;

    return Offset(
      imageX.clamp(0.0, _imageSize.width.toDouble()),
      imageY.clamp(0.0, _imageSize.height.toDouble()),
    );
  }

  void _onScaleStart(ScaleStartDetails details) {
    _lastFocalPoint = details.focalPoint;
    _lastScale = _currentScale;
    _targetScale = _currentScale;
    _targetOffset = _currentOffset;

    if (details.pointerCount != 1) {
      setState(() {
        _isZooming = true;
        _isPanning = false;
      });
      return;
    }

    if (widget.currentTool == SelectionTool.hand) {
      setState(() {
        _isPanning = true;
        _isZooming = false;
      });
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    _currentPointerCount = details.pointerCount;

    final bool nowZooming = _currentPointerCount != 1;
    if (nowZooming != _isZooming) {
      setState(() {
        _isZooming = nowZooming;
        if (_isZooming) {
          _isPanning = false;
        }
      });
    }

    if (widget.isSegmentationModeActive && _currentPointerCount != 1) {
      return;
    }

    if (_currentPointerCount == 1) {
      if (_isPanning) {
        final delta = details.focalPoint - _lastFocalPoint!;
        setState(() {
          _targetOffset += delta;
        });
        _lastFocalPoint = details.focalPoint;
      }
    } else {
      _lastScale ??= _currentScale;
      _lastFocalPoint ??= details.focalPoint;

      if (details.scale != 1.0) {
        final oldScale = _targetScale;
        _targetScale = (_lastScale! * details.scale).clamp(1.0, 3.0);

        if (oldScale != _targetScale && oldScale > 0) {
          final scaleChange = _targetScale / oldScale;
          final focalDelta = details.focalPoint - _lastFocalPoint!;
          _targetOffset = _targetOffset - focalDelta * (scaleChange - 1.0);
        }
      }

      if (details.focalPoint != _lastFocalPoint) {
        final delta = details.focalPoint - _lastFocalPoint!;
        _targetOffset += delta;
        _lastFocalPoint = details.focalPoint;
      }
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    if (_isZooming) {
      setState(() {
        _isZooming = false;
      });
    }

    if (_isPanning) {
      setState(() {
        _isPanning = false;
      });
    }

    _lastFocalPoint = null;
    _lastScale = null;
    _currentPointerCount = 0;
  }
}

class _SelectionCanvasPainter extends CustomPainter {
  final ui.Image? image;
  final ui.Image? previewImage;
  final Uint8List selectionMask;
  final Size imageSize;
  final double currentScale;
  final Offset currentOffset;
  final bool isZooming;
  final bool isPanning;
  final double maskAnimationValue;

  _SelectionCanvasPainter({
    required this.image,
    this.previewImage,
    required this.selectionMask,
    required this.imageSize,
    this.currentScale = 1.0,
    this.currentOffset = Offset.zero,
    this.isZooming = false,
    this.isPanning = false,
    this.maskAnimationValue = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF151412);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    if (image == null) return;

    final containScaleX = size.width / imageSize.width;
    final containScaleY = size.height / imageSize.height;
    final containScale = math.min(containScaleX, containScaleY);
    final baseWidth = imageSize.width * containScale;
    final baseHeight = imageSize.height * containScale;
    final baseOffsetX = (size.width - baseWidth) / 2;
    final baseOffsetY = (size.height - baseHeight) / 2;

    final srcWidth = imageSize.width / currentScale;
    final srcHeight = imageSize.height / currentScale;

    final pixelsPerImageX = srcWidth / baseWidth;
    final pixelsPerImageY = srcHeight / baseHeight;

    final srcX =
        ((imageSize.width - srcWidth) / 2 - currentOffset.dx * pixelsPerImageX)
            .clamp(0.0, imageSize.width - srcWidth)
            .toDouble();
    final srcY =
        ((imageSize.height - srcHeight) / 2 -
                currentOffset.dy * pixelsPerImageY)
            .clamp(0.0, imageSize.height - srcHeight)
            .toDouble();

    final imagePaint = Paint();
    canvas.drawImageRect(
      image!,
      Rect.fromLTWH(srcX, srcY, srcWidth, srcHeight),
      Rect.fromLTWH(baseOffsetX, baseOffsetY, baseWidth, baseHeight),
      imagePaint,
    );

    if (previewImage != null) {
      canvas.drawImageRect(
        previewImage!,
        Rect.fromLTWH(srcX, srcY, srcWidth, srcHeight),
        Rect.fromLTWH(baseOffsetX, baseOffsetY, baseWidth, baseHeight),
        Paint(),
      );
    }

    final scaleX = baseWidth / srcWidth;
    final scaleY = baseHeight / srcHeight;

    if (selectionMask.isNotEmpty) {
      _drawSelectionOverlay(
        canvas,
        size,
        baseOffsetX,
        baseOffsetY,
        baseWidth,
        baseHeight,
        scaleX,
        scaleY,
        srcX,
        srcY,
        srcWidth,
        srcHeight,
      );
    }
  }

  void _drawSelectionOverlay(
    Canvas canvas,
    Size size,
    double offsetX,
    double offsetY,
    double drawWidth,
    double drawHeight,
    double scaleX,
    double scaleY,
    double srcX,
    double srcY,
    double srcWidth,
    double srcHeight,
  ) {
    final imgWidth = imageSize.width.toInt();
    final imgHeight = imageSize.height.toInt();
    final visibleWidth = srcWidth;
    final visibleHeight = srcHeight;

    final overlayPaint = Paint()
      ..color = Colors.blue.withAlpha(
        (0.3 * (0.5 + 0.5 * maskAnimationValue) * 255).round(),
      )
      ..style = PaintingStyle.fill;

    for (int y = 0; y < imgHeight; y += 4) {
      if (y < srcY || y >= srcY + visibleHeight) continue;

      int x = 0;
      while (x < imgWidth) {
        if (x < srcX) {
          x++;
          continue;
        }
        if (x >= srcX + visibleWidth) break;

        while (x < imgWidth) {
          if (x >= srcX + visibleWidth) break;
          final idx = y * imgWidth + x;
          if (idx < selectionMask.length && selectionMask[idx] == 1) break;
          x++;
        }
        if (x >= imgWidth || x >= srcX + visibleWidth) break;
        int startX = x;
        while (x < imgWidth) {
          if (x >= srcX + visibleWidth) break;
          final idx = y * imgWidth + x;
          if (idx >= selectionMask.length || selectionMask[idx] != 1) break;
          x++;
        }
        int endX = x - 1;
        final screenX = offsetX + (startX - srcX) * scaleX;
        final screenY = offsetY + (y - srcY) * scaleY;
        final screenWidth = (endX - startX + 1) * scaleX;
        final screenHeight = scaleY * 4;
        canvas.drawRect(
          Rect.fromLTWH(screenX, screenY, screenWidth, screenHeight),
          overlayPaint,
        );
      }
    }

    for (int x = 0; x < imgWidth; x += 4) {
      if (x < srcX || x >= srcX + visibleWidth) continue;

      int y = 0;
      while (y < imgHeight) {
        if (y < srcY) {
          y++;
          continue;
        }
        if (y >= srcY + visibleHeight) break;

        while (y < imgHeight) {
          if (y >= srcY + visibleHeight) break;
          final idx = y * imgWidth + x;
          if (idx < selectionMask.length && selectionMask[idx] == 1) break;
          y++;
        }
        if (y >= imgHeight || y >= srcY + visibleHeight) break;
        int startY = y;
        while (y < imgHeight) {
          if (y >= srcY + visibleHeight) break;
          final idx = y * imgWidth + x;
          if (idx >= selectionMask.length || selectionMask[idx] != 1) break;
          y++;
        }
        int endY = y - 1;
        final screenX = offsetX + (x - srcX) * scaleX;
        final screenY = offsetY + (startY - srcY) * scaleY;
        final screenWidth = scaleX * 4;
        final screenHeight = (endY - startY + 1) * scaleY;
        canvas.drawRect(
          Rect.fromLTWH(screenX, screenY, screenWidth, screenHeight),
          overlayPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SelectionCanvasPainter oldDelegate) {
    return image != oldDelegate.image ||
        previewImage != oldDelegate.previewImage ||
        selectionMask != oldDelegate.selectionMask ||
        imageSize != oldDelegate.imageSize ||
        currentScale != oldDelegate.currentScale ||
        currentOffset != oldDelegate.currentOffset ||
        isZooming != oldDelegate.isZooming ||
        isPanning != oldDelegate.isPanning ||
        maskAnimationValue != oldDelegate.maskAnimationValue;
  }
}
