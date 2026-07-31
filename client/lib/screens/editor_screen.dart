import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../models/selection_tool.dart';
import '../widgets/selection_canvas.dart';
import '../services/segmentation_service.dart';
import 'color_palette_screen.dart';
import 'material_selection_screen.dart';
import '../utils/app_localizations.dart';
import '../utils/transitions.dart';
import 'camera_page.dart';
import 'export_screen.dart';
import 'projects_screen.dart';
import '../widgets/video_loading_overlay.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen>
    with TickerProviderStateMixin {
  // Local state
  SelectionTool _selectedTool = SelectionTool.interactiveSegmentation;
  final double _brushSize = 30;

  // Segmentation service
  late final SegmentationService _segmentationService;

  // FAB animation
  late AnimationController _fabPulseController;
  late Animation<double> _fabPulseAnimation;

  // State for segmentation mode (toggle)
  bool _isSegmentationModeActive = false;

  // State for recolor quality
  bool _isComplexRecolorMode = false;

  // FAB initialization (first press just activates)
  bool _fabInitialized = false;

  // Guard against multiple concurrent segmentations
  bool _isProcessing = false;

  // Last tap position for AI recolor fallback
  Offset? _lastTapImagePosition;
  Size? _lastImageSize;
  Uint8List? _lastImageBytes;

  @override
  void initState() {
    super.initState();
    _segmentationService = SegmentationService();
    _fabPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _fabPulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _fabPulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _segmentationService.dispose();
    _fabPulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2C2C2E),
      body: Stack(
        children: [
          // Canvas area — isolated rebuild scope via RepaintBoundary
          Positioned.fill(
            bottom: 220,
            child: Consumer<AppState>(
              builder: (context, appState, child) {
                final imageBytes = appState.capturedImage;
                final previewBytes = appState.previewImage;

                if (imageBytes == null) {
                  return const _EmptyCanvasPlaceholder();
                }

                return RepaintBoundary(
                  child: MouseRegion(
                    cursor: SystemMouseCursors.basic,
                    child: SelectionCanvas(
                      key: const ValueKey('selection_canvas'),
                      imageBytes: imageBytes,
                      previewImage: previewBytes,
                      selectionMask: (appState.isPreviewMode && appState.previewImage != null) ? Uint8List(0) : appState.selectionMask,
                      currentTool: _selectedTool,
                      brushSize: _brushSize,
                      lassoPoints: const [],
                      polygonPoints: const [],
                      rectanglePoints: const [],
                      boundaryPoints: const [],
                      onSelectionUpdate: appState.setSelectionMask,
                      onLassoPointsUpdate: (_) {},
                      onPolygonPointsUpdate: (_) {},
                      onRectanglePointsUpdate: (_) {},
                      onBoundaryStart: null,
                      onBoundaryPoint: null,
                      onBoundaryEnd: null,
                      onDrawingStart: () {},
                      onDrawingEnd: () {},
                      onAutoSegmentTap:
                          _selectedTool ==
                                  SelectionTool.interactiveSegmentation &&
                              _fabInitialized &&
                              _isSegmentationModeActive
                          ? _handleAutoSegmentation
                          : null,
                      onPickColorTap: _selectedTool == SelectionTool.eyedropper
                          ? _handlePickColor
                          : null,
                      isSegmentationModeActive: _isSegmentationModeActive,
                    ),
                  ),
                );
              },
            ),
          ),

          // Top toolbar — extracted to own widget to avoid canvas rebuilds
          _EditorTopToolbar(
            onBackToCamera: () => _onBackToCamera(context),
            onGoHome: () => Navigator.push(
              context,
              AppTransitions.fadeRoute(const ProjectsScreen()),
            ),
          ),

          // Bottom panel — state method for direct access to stateful FAB
          _buildBottomPanel(),

          // Loading overlay with transparent looping video
          Consumer<AppState>(
            builder: (context, appState, child) {
              if (!appState.isLoading) return const SizedBox.shrink();
              return VideoLoadingOverlay(
                visible: true,
                message: AppLocalizations.tr(context, 'ai_recoloring'),
              );
            },
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BOTTOM PANEL
  // ============================================================

  Widget _buildBottomPanel() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Color(0xFF1C1C1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 68,
              child: Stack(
                children: [
                  const Center(child: SizedBox(width: 68, height: 68)),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: _buildRecolorToggle(),
                    ),
                  ),
                  Center(child: _buildAutoSegmentationFAB()),
                ],
              ),
            ),
            const SizedBox(height: 36),
            // Bottom actions row - centered, color picker hidden
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _BottomAction(
                  child: const _IconInFrameWidget(
                    assetPath: 'assets/icons/Paint Palette.png',
                    size: 48,
                  ),
                  label: AppLocalizations.tr(context, 'palette'),
                  onTap: () => _showColorPalette(context),
                ),
                const SizedBox(width: 36),
                _EyedropperButton(
                  isSelected: _selectedTool == SelectionTool.eyedropper,
                  onTap: () {
                    setState(() {
                      if (_selectedTool == SelectionTool.eyedropper) {
                        _selectedTool = SelectionTool.interactiveSegmentation;
                        _isSegmentationModeActive = false;
                      } else {
                        _selectedTool = SelectionTool.eyedropper;
                        _isSegmentationModeActive = false;
                      }
                    });
                  },
                ),
                const SizedBox(width: 36),
                _BottomAction(
                  child: const _IconInFrameWidget(
                    assetPath: 'assets/icons/Diagonal Lines.png',
                    size: 48,
                  ),
                  label: AppLocalizations.tr(context, 'material'),
                  onTap: () => _showMaterialSelection(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // AUTO-SEGMENTATION FAB
  // ============================================================

  Widget _buildRecolorToggle() {
    final bool complex = _isComplexRecolorMode;

    const double trackWidth = 160;
    const double trackHeight = 44;
    const double thumbSize = 54;

    TextStyle labelStyle(bool active) => TextStyle(
          color: active ? Colors.black : Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        );

    return GestureDetector(
      onTap: () {
        setState(() {
          _isComplexRecolorMode = !_isComplexRecolorMode;
        });
      },
      child: Container(
        width: trackWidth,
        height: trackHeight,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(trackHeight / 2),
          border: Border.all(color: Colors.white24, width: 1),
        ),
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOut,
              alignment: complex ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: thumbSize,
                height: thumbSize,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC107),
                  borderRadius: BorderRadius.circular(thumbSize / 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0xFFFFC107),
                      blurRadius: 14,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Center(
                    child: Text(AppLocalizations.tr(context, 'easy'), style: labelStyle(!complex)),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(AppLocalizations.tr(context, 'complex'), style: labelStyle(complex)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAutoSegmentationFAB() {
    final bool isActive = _isSegmentationModeActive && _fabInitialized;

    return AnimatedBuilder(
      animation: _fabPulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _fabPulseAnimation.value,
          child: child,
        );
      },
      child: GestureDetector(
        onTap: () {
          if (_isProcessing) return;
          setState(() {
            if (!_fabInitialized) {
              _fabInitialized = true;
              _isSegmentationModeActive = true;
            } else {
              _isSegmentationModeActive = !_isSegmentationModeActive;
            }
          });
        },
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 300),
          tween: Tween(begin: 0.0, end: 1.0),
          curve: Curves.easeOutBack,
          builder: (context, animValue, child) {
            return Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? const Color(0xFFFFC107) : Colors.grey,
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: const Color(0xFFFFC107).withValues(alpha: 0.5 * animValue),
                          blurRadius: 20 * animValue,
                          spreadRadius: 4 * animValue,
                        ),
                      ]
                    : [],
              ),
              child: child,
            );
          },
          child: Center(
            child: Image.asset(
              'assets/icons/Hand Cursor.png',
              width: 32,
              height: 32,
              color: isActive ? Colors.white : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SEGMENTATION
  // ============================================================

  /// Обрабатывает клик для авто-сегментации объекта с AI-перекраской.
  /// Координаты уже преобразованы в пространство исходного изображения.
  Future<void> _handleAutoSegmentation(Uint8List orientedBytes, Offset imagePosition, int imageWidth, int imageHeight) async {
    _lastTapImagePosition = imagePosition;
    _lastImageSize = Size(imageWidth.toDouble(), imageHeight.toDouble());
    _lastImageBytes = orientedBytes;
    final appState = context.read<AppState>();
    await _runAIRecolor(
      orientedBytes,
      imagePosition,
      Size(imageWidth.toDouble(), imageHeight.toDouble()),
      colorName: appState.selectedColorName,
      fromPipette: appState.isColorFromPipette,
    );
  }

  Future<void> _runAIRecolor(Uint8List orientedBytes, Offset imagePosition, Size imageSize, {String? colorName, bool fromPipette = false}) async {
    if (_isProcessing) return;
    _isProcessing = true;

    final appState = context.read<AppState>();

    if (appState.isLoading) {
      _isProcessing = false;
      return;
    }

    appState.setLoading(true);
    appState.setPreviewImage(null);
    if (appState.isPreviewMode) appState.togglePreviewMode();

    try {
      // Use already-oriented bytes from the canvas
      debugPrint('AI recolor: position=$imagePosition, imageSize=$imageSize');
      debugPrint('[DEBUG] material=${appState.selectedMaterial}, colorName=$colorName, colorHex=${appState.selectedColor.toARGB32()}, selectedColorName=${appState.selectedColorName}');

final resultBytes = await _segmentationService.segmentObject(
        imageBytes: orientedBytes,
        imagePosition: imagePosition,
        imageWidth: imageSize.width.toInt(),
        imageHeight: imageSize.height.toInt(),
        material: appState.selectedMaterial,
        colorHex: appState.selectedColor.toARGB32(),
        colorName: colorName,
        patina: appState.patinaMode,
        objectName: 'object',
        strength: 1.0,
        guidanceScale: 5.0,
        numInferenceSteps: _isComplexRecolorMode ? 30 : 6,
        fromPipette: fromPipette,
      );

      if (!mounted) {
        _isProcessing = false;
        appState.setLoading(false);
        return;
      }

      if (resultBytes != null) {
        appState.setPreviewImage(resultBytes);
        if (!appState.isPreviewMode) appState.togglePreviewMode();
        appState.addProject(resultBytes);

        final imageProvider = MemoryImage(resultBytes);
        await precacheImage(imageProvider, context);

        if (mounted) {
          Navigator.push(
            context,
            AppTransitions.slideRoute(
              const ExportScreen(),
              direction: SlideDirection.up,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(
            content: Text(AppLocalizations.tr(
                context, 'ai_recolor_error'))));
      }
    } catch (e) {
      debugPrint('Ошибка AI: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${AppLocalizations.tr(context, 'ai_error')}: $e')));
      }
    } finally {
      _isProcessing = false;
      if (mounted) {
        appState.setLoading(false);
      }
    }
  }

  // ============================================================
  // EYEDROPPER
  // ============================================================

  /// Вызывается при тапе пипеткой: берёт цвет точки и выбирает его как
  /// активный (как будто выбрали в палитре). Сама перекраска не
  /// запускается — пользователь затем нажимает FAB и выбирает объект.
  /// Инструмент срабатывает один раз и сбрасывается после выбора цвета.
  void _handlePickColor(Uint8List orientedBytes, Offset imagePosition, int imageWidth, int imageHeight, Color pickedColor) {
    if (_isProcessing) return;

    setState(() {
      _selectedTool = SelectionTool.interactiveSegmentation;
      _isSegmentationModeActive = false;
    });

    final appState = context.read<AppState>();
    final colorHex = '#${pickedColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
    appState.setSelectedColor(pickedColor);
    appState.setSelectedColorName(colorHex, fromPipette: true);

    _lastTapImagePosition = imagePosition;
    _lastImageSize = Size(imageWidth.toDouble(), imageHeight.toDouble());
    _lastImageBytes = orientedBytes;

    _showColorPickedBanner(pickedColor);
  }

  void _showColorPickedBanner(Color pickedColor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white24, width: 1),
        ),
        content: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: pickedColor,
                border: Border.all(color: Colors.white38, width: 1.5),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: pickedColor.withValues(alpha: 0.5),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppLocalizations.tr(context, 'color_picked_with_eyedropper'),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '#${pickedColor.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase().substring(2)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _showMaterialSelection(BuildContext context) async {
    final result = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const MaterialSelectionScreen(),
    );
    if (!mounted) return;
    if (result != null) {
      if (mounted) {
        context.read<AppState>().setSelectedMaterial(result);
      }
    }
    if (mounted) {
      await _showColorPalette(context);
    }
  }

  Future<void> _showColorPalette(BuildContext context) async {
    final appState = context.read<AppState>();
    final result = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ColorPaletteScreen(),
    );
    if (!mounted) return;
    if (result != null) {
      appState.setSelectedColor(result['color']);
      final colorName = result['colorName'] as String?;
      appState.setSelectedColorName(colorName);
      if (_lastImageBytes != null && _lastTapImagePosition != null && _lastImageSize != null) {
        await _runAIRecolor(_lastImageBytes!, _lastTapImagePosition!, _lastImageSize!, colorName: colorName);
      }
    }
  }

  void _onBackToCamera(BuildContext context) {
    final appState = context.read<AppState>();
    appState.setCapturedImage(null);
    appState.resetSelection();
    appState.setStage(AppStage.camera);
    Navigator.pushReplacement(
      context,
      AppTransitions.fadeRoute(const CameraPage()),
    );
  }
}

// ============================================================
// EXTRACTED WIDGETS — isolated rebuild scopes
// ============================================================

/// Placeholder shown when no image is captured — const widget, never rebuilds
class _EmptyCanvasPlaceholder extends StatelessWidget {
  const _EmptyCanvasPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF2C2C2E),
      child: const Center(
        child: Icon(Icons.image, color: Colors.white24, size: 80),
      ),
    );
  }
}

/// Top toolbar — separate widget so it never triggers canvas rebuilds
class _EditorTopToolbar extends StatelessWidget {
  final VoidCallback onBackToCamera;
  final VoidCallback onGoHome;

  const _EditorTopToolbar({
    required this.onBackToCamera,
    required this.onGoHome,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _TopIconBtn('assets/icons/Vector.png', onTap: onBackToCamera),
            _TopIconBtn('assets/icons/home.png', onTap: onGoHome),
          ],
        ),
      ),
    );
  }
}

/// Icon button for the top toolbar
class _TopIconBtn extends StatelessWidget {
  final String assetPath;
  final VoidCallback onTap;

  const _TopIconBtn(this.assetPath, {required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          color: Colors.white12,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Image.asset(
            assetPath,
            width: 22,
            height: 22,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Bottom action button with icon and label
class _BottomAction extends StatelessWidget {
  final Widget child;
  final String label;
  final VoidCallback onTap;

  const _BottomAction({
    required this.child,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: child,
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// Icon in frame - for palette and material icons
class _IconInFrameWidget extends StatelessWidget {
  final String assetPath;
  final double size;

  const _IconInFrameWidget({required this.assetPath, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            'assets/icons/ramka.png',
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
          Image.asset(
            assetPath,
            width: size * 0.65,
            height: size * 0.65,
            color: Colors.white,
          ),
        ],
      ),
    );
  }
}

/// Eyedropper button — circular frame that turns orange (like the FAB)
/// when the eyedropper tool is selected. Sized to match the other bottom
/// actions (Palette / Material) so labels align on the same baseline.
class _EyedropperButton extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;

  const _EyedropperButton({required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const double iconSize = 48;
    const Color fabOrange = Color(0xFFFFC107);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Container(
              width: iconSize,
              height: iconSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2C2C2E),
                border: Border.all(
                  color: isSelected ? fabOrange : Colors.white24,
                  width: isSelected ? 3 : 1.5,
                ),
              ),
              child: Center(
                child: _EyedropperIcon(size: iconSize, iconScale: 0.55),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            AppLocalizations.tr(context, 'eyedropper'),
            style: TextStyle(
              color: isSelected ? fabOrange : Colors.white70,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

/// Eyedropper icon shown without white tint so the original colorful
/// asset (Color Dropper_layerstyle.png) is displayed as-is.
class _EyedropperIcon extends StatelessWidget {
  final double size;
  final double iconScale;

  const _EyedropperIcon({this.size = 24, this.iconScale = 0.7});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            'assets/icons/ramka.png',
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
          Image.asset(
            'assets/icons/Color Dropper_layerstyle.png',
            width: size * iconScale,
            height: size * iconScale,
          ),
        ],
      ),
    );
  }
}
