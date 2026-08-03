import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import '../models/app_state.dart';
import '../utils/app_localizations.dart';
import '../utils/transitions.dart';
import 'editor_screen.dart';
import 'projects_screen.dart';

Uint8List _fixImageOrientation(Uint8List bytes) {
  try {
    img.Image? decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;

    decoded = img.bakeOrientation(decoded);
    return Uint8List.fromList(img.encodeJpg(decoded));
  } catch (e) {
    debugPrint('Orientation fix error: $e');
    return bytes;
  }
}

/// Runs the (heavy) orientation fix on a background isolate so it never
/// blocks the UI thread during navigation.
Future<Uint8List> _fixImageOrientationAsync(Uint8List bytes) {
  return compute(_fixImageOrientation, bytes);
}

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  final ImagePicker _picker = ImagePicker();
  bool _isCameraInitialized = false;
  int _currentCameraIndex = 0;
  double _selectedZoom = 1.0;
  bool _isFlashOn = false;
  Offset? _focusPoint;
  double _baseZoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 4.0;

  

  Future<void> _initializeCamera([int? cameraIndex]) async {
    PermissionStatus cameraStatus = await Permission.camera.request();
    if (!cameraStatus.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppLocalizations.tr(
                  context, 'camera_requires_permission'))),
        );
      }
      return;
    }

    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        await _cameraController?.dispose();

        final index = cameraIndex ?? _currentCameraIndex;
        if (index >= _cameras!.length) {
          _currentCameraIndex = 0;
        } else {
          _currentCameraIndex = index;
        }

        _cameraController = CameraController(
          _cameras![_currentCameraIndex],
          ResolutionPreset.high,
          enableAudio: false,
        );
        await _cameraController!.initialize();

        try {
          _minZoom = await _cameraController!.getMinZoomLevel();
          _maxZoom = await _cameraController!.getMaxZoomLevel();
          _selectedZoom = _selectedZoom.clamp(_minZoom, _maxZoom);
        } catch (e) {
          debugPrint('Error getting zoom range: $e');
        }

        try {
          await _cameraController!.setZoomLevel(_selectedZoom);
        } catch (e) {
          debugPrint('Error setting initial zoom: $e');
        }

        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Camera initialization error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(
            content: Text(
                '${AppLocalizations.tr(context, 'camera_error')}: $e')));
      }
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppLocalizations.tr(
                  context, 'camera_switch_unavailable'))),
        );
      }
      return;
    }

    // Отключаем вспышку перед переключением камеры
    if (_isFlashOn &&
        _cameraController != null &&
        _cameraController!.value.isInitialized) {
      try {
        await _cameraController!.setFlashMode(FlashMode.off);
        _isFlashOn = false;
        if (mounted) setState(() {});
      } catch (e) {
        debugPrint('Error turning off flash: $e');
      }
    }

    // Detach the current preview before disposing the controller to avoid
    // a crash from CameraPreview referencing an already-disposed controller.
    if (mounted) {
      setState(() {
        _isCameraInitialized = false;
      });
    }

    await _cameraController?.dispose();
    _cameraController = null;
    _selectedZoom = 1.0;

    final newIndex = (_currentCameraIndex + 1) % _cameras!.length;
    await _initializeCamera(newIndex);
  }

  Future<void> _takePicture() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      final XFile image = await _cameraController!.takePicture();
      final bytes = await image.readAsBytes();

      if (!mounted) return;

      // Navigate immediately with the raw bytes for an instant transition,
      // then fix orientation in a background isolate and update the image.
      final appState = context.read<AppState>();
      appState.setCapturedImage(bytes);
      Navigator.push(
        context,
        AppTransitions.slideRoute(
          const EditorScreen(),
          direction: SlideDirection.left,
          duration: const Duration(milliseconds: 180),
        ),
      );

      _fixImageOrientationAsync(bytes).then((fixed) {
        if (!identical(fixed, bytes)) {
          appState.setCapturedImage(fixed);
        }
      });
    } catch (e) {
      debugPrint('Error taking picture: $e');
    }
  }

  void _scheduleZoom(double zoom) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    _cameraController!.setZoomLevel(zoom).catchError((e) {
      debugPrint('Error setting zoom: $e');
    });
  }

  void _onCameraTap(TapDownDetails details) {
    if (_isCameraInitialized && _cameraController != null) {
      final Offset tapPosition = details.localPosition;
      final Size screenSize = MediaQuery.of(context).size;
      
      // Вычисляем точки фокусировки в пространстве камеры
      // CameraController.setFocusPoint accepts values normalized to 0-1
      final double focusX = (tapPosition.dx / screenSize.width).clamp(0.0, 1.0);
      final double focusY = (tapPosition.dy / screenSize.height).clamp(0.0, 1.0);
      
      // Устанавливаем точку фокусировки камеры
      _cameraController!.setFocusPoint(Offset(focusX, focusY));
      
      // Store the screen position for the focus frame
      setState(() {
        _focusPoint = tapPosition;
      });
      
      // Скрываем фокусную рамку через 2 секунды
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _focusPoint = null;
          });
        }
      });
    }
  }

  Future<void> _toggleFlash() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      _isFlashOn = !_isFlashOn;
      await _cameraController!.setFlashMode(
        _isFlashOn ? FlashMode.always : FlashMode.off,
      );
      setState(() {});
    } catch (e) {
      debugPrint('Error toggling flash: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    if (_isFlashOn && _cameraController != null) {
      try {
        _cameraController!.setFlashMode(FlashMode.off);
      } catch (e) {
        debugPrint('Error turning off flash in dispose: $e');
      }
    }
    _cameraController?.dispose();
    super.dispose();
  }

@override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF151412),
      body: Stack(
        children: [
          Center(
              child: _isCameraInitialized && _cameraController != null
                  ? GestureDetector(
                      onScaleStart: (details) {
                        _baseZoom = _selectedZoom;
                      },
                      onScaleUpdate: (details) {
                        if (details.pointerCount == 2) {
                          final newZoom = (_baseZoom * details.scale)
                              .clamp(_minZoom, _maxZoom);
                          setState(() => _selectedZoom = newZoom);
                          _scheduleZoom(newZoom);
                        }
                      },
                      onScaleEnd: (details) {},
                      child: CameraPreview(_cameraController!),
                    )
                  : const SizedBox.expand(),
          ),
          // Manual focus overlay - tappable anywhere for manual focus
          Positioned.fill(
            child: GestureDetector(
              onTapDown: (details) => _onCameraTap(details),
              behavior: HitTestBehavior.translucent,
              child: const SizedBox(),
            ),
          ),
          // Focus frame overlay - shows at tapped position when manual focus is active
          if (_focusPoint != null)
            Positioned(
              left: _focusPoint!.dx - 40,
              top: _focusPoint!.dy - 40,
              child: SizedBox(
                width: 80,
                height: 80,
                child: CustomPaint(painter: _FocusFramePainter()),
              ),
            ),
          // Top buttons overlay
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _TopButton(
                    iconPath: 'assets/icons/home.png',
                    onTap: () async {
                      final navigator = Navigator.of(context);
                      if (_isFlashOn &&
                          _cameraController != null &&
                          _cameraController!.value.isInitialized) {
                        try {
                          await _cameraController!.setFlashMode(FlashMode.off);
                          _isFlashOn = false;
                          if (mounted) setState(() {});
                        } catch (e) {
                          debugPrint('Error turning off flash: $e');
                        }
                      }
                      if (!mounted) return;
                      navigator.pushAndRemoveUntil(
                        AppTransitions.fadeRoute(const ProjectsScreen()),
                        (route) => false,
                      );
                    },
                  ),
                  _TopButton(
                    iconPath: 'assets/icons/light.png',
                    onTap: _toggleFlash,
                    isActive: _isFlashOn,
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              color: const Color(0xFF151412),
              padding: const EdgeInsets.only(bottom: 32, top: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1C),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_selectedZoom.toStringAsFixed(1)}x',
                      style: const TextStyle(
                        color: Color(0xFFF5A623),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      GestureDetector(
                        onTap: _pickFromGallery,
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: const Color(0xFF404040),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Image.asset(
                              'assets/icons/Add_Image.png',
                              width: 26,
                              height: 26,
                            ),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _takePicture,
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.45),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _switchCamera,
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: const Color(0xFF404040),
                            borderRadius: BorderRadius.circular(14),
                          ),
child: Center(
                             child: Image.asset(
                               'assets/icons/frontalka.png',
                               width: 26,
                               height: 26,
                             ),
                           ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFromGallery() async {
    PermissionStatus status;
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      status = await Permission.photos.request();
    } else {
      // Android: используем Permission.photos для Android 13+ (API 33+), иначе storage
      try {
        status = await Permission.photos.request();
        if (!status.isGranted) {
          status = await Permission.storage.request();
        }
      } catch (e) {
        // Если Permission.photos не поддерживается (Android <13), используем storage
        status = await Permission.storage.request();
      }
    }

    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.tr(
                context, 'gallery_permission_required')),
          ),
        );
      }
      return;
    }

    try {
      // Отключаем вспышку перед открытием галереи
      if (_isFlashOn &&
          _cameraController != null &&
          _cameraController!.value.isInitialized) {
        await _cameraController!.setFlashMode(FlashMode.off);
        _isFlashOn = false;
        if (mounted) setState(() {});
      }

      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        imageQuality: 100,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        debugPrint('Picked image from gallery: ${bytes.length} bytes');

        if (mounted) {
          final appState = context.read<AppState>();
          appState.setCapturedImage(bytes);
          Navigator.push(
            context,
            AppTransitions.slideRoute(
              const EditorScreen(),
              direction: SlideDirection.left,
              duration: const Duration(milliseconds: 180),
            ),
          );

          _fixImageOrientationAsync(bytes).then((fixed) {
            if (!identical(fixed, bytes)) {
              appState.setCapturedImage(fixed);
            }
          });
        }
      } else {
        debugPrint('No image selected from gallery');
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${AppLocalizations.tr(context, 'error_selecting_image')}: $e')),
        );
      }
    }
  }
}

class _TopButton extends StatelessWidget {
  final String iconPath;
  final VoidCallback? onTap;
  final bool isActive;
  const _TopButton({
    required this.iconPath,
    this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFFFC107) : Colors.white12,
          shape: BoxShape.circle,
          border: isActive ? Border.all(color: Colors.white, width: 2) : null,
        ),
        child: Center(
          child: Image.asset(
            iconPath,
            width: 22,
            height: 22,
            color: isActive ? Colors.black : Colors.white,
          ),
        ),
      ),
    );
  }
}

class _FocusFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const cornerLen = 16.0;
    final w = size.width;
    final h = size.height;

    final paths = [
      [Offset(0, cornerLen), Offset(0, 0), Offset(cornerLen, 0)],
      [Offset(w - cornerLen, 0), Offset(w, 0), Offset(w, cornerLen)],
      [Offset(0, h - cornerLen), Offset(0, h), Offset(cornerLen, h)],
      [Offset(w - cornerLen, h), Offset(w, h), Offset(w, h - cornerLen)],
    ];

    for (final pts in paths) {
      final path = Path()
        ..moveTo(pts[0].dx, pts[0].dy)
        ..lineTo(pts[1].dx, pts[1].dy)
        ..lineTo(pts[2].dx, pts[2].dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
