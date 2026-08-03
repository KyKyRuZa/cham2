import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/recolor_state.dart';
import '../models/settings_state.dart';
import '../utils/app_localizations.dart';
import '../utils/transitions.dart';
import 'projects_screen.dart';

class ExportScreen extends StatefulWidget {
  final Uint8List? initialImageBytes;

  const ExportScreen({super.key, this.initialImageBytes});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  bool _isCompareHeld = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  String _cachedNoImage = '';
  String _cachedNoGalleryPermission = '';
  String _cachedPhotoSaved = '';
  String _cachedErrorSaving = '';
  String _cachedShareText = '';
  String _cachedErrorSending = '';
  String _cachedOriginal = '';
  String _cachedRecolor = '';

  void _cacheTranslations(BuildContext context) {
    _cachedNoImage = AppLocalizations.tr(context, 'no_image');
    _cachedNoGalleryPermission = AppLocalizations.tr(context, 'no_gallery_save_permission');
    _cachedPhotoSaved = AppLocalizations.tr(context, 'photo_saved_to_gallery');
    _cachedErrorSaving = AppLocalizations.tr(context, 'error_saving_to_gallery');
    _cachedShareText = AppLocalizations.tr(context, 'share_text');
    _cachedErrorSending = AppLocalizations.tr(context, 'error_sending');
    _cachedOriginal = AppLocalizations.tr(context, 'original');
    _cachedRecolor = AppLocalizations.tr(context, 'recolor');
  }

  @override
  Widget build(BuildContext context) {
    _cacheTranslations(context);
    final capturedImage = context.select<RecolorState, Uint8List?>((s) => s.capturedImage);
    final previewImage = context.select<RecolorState, Uint8List?>((s) => s.previewImage);
    final displayImage = _isCompareHeld && capturedImage != null
        ? capturedImage
        : (widget.initialImageBytes ?? previewImage ?? capturedImage);

    return Scaffold(
      backgroundColor: const Color(0xFF151412),
      appBar: AppBar(
        backgroundColor: const Color(0xFF151412),
        foregroundColor: Colors.white,
        title: Text(AppLocalizations.tr(context, 'result')),
        leading: GestureDetector(
            onTap: () {
              final settingsState = context.read<SettingsState>();
              final recolorState = context.read<RecolorState>();
              recolorState.setPreviewImage(null);
              if (settingsState.isPreviewMode) {
                settingsState.togglePreviewMode();
              }
              Navigator.pop(context);
            },
            child: Container(
            width: 44,
            height: 44,
            margin: const EdgeInsets.only(left: 8),
            decoration: const BoxDecoration(
              color: Colors.white12,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
          ),
        ),
        actions: [
            GestureDetector(
              onTap: () {
                context.read<RecolorState>().setCapturedImage(null);
                Navigator.pushAndRemoveUntil(
                  context,
                  AppTransitions.fadeRoute(const ProjectsScreen()),
                  (route) => false,
                );
              },
              child: Container(
                width: 44,
                height: 44,
                margin: const EdgeInsets.only(right: 8),
                decoration: const BoxDecoration(
                  color: Colors.white12,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Image.asset(
                    'assets/icons/home.png',
                    width: 22,
                    height: 22,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _buildImageDisplay(displayImage),
          ),
          Container(
            color: const Color(0xFF151412),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildCompareButton(),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: () => _saveImage(context, displayImage),
                    icon: const Icon(Icons.download, size: 24),
                     label: Text(
                       AppLocalizations.tr(context, 'download'),
                       style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                     ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF5C518),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: () => _shareImage(context, displayImage),
                    icon: const Icon(Icons.share, size: 24),
                     label: Text(
                       AppLocalizations.tr(context, 'send'),
                       style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                     ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF404040),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageDisplay(Uint8List? displayImage) {
    if (displayImage == null) {
      return Center(
        child: Text(_cachedNoImage, style: const TextStyle(color: Colors.white)),
      );
    }

    final imageProvider = MemoryImage(displayImage);

    return InteractiveViewer(
      minScale: 1.0,
      maxScale: 4.0,
      child: Center(
        child: Image(
          image: imageProvider,
          fit: BoxFit.contain,
          gaplessPlayback: true,
        ),
      ),
    );
  }

  Widget _buildCompareButton() {
    final hasOriginal = context.select<RecolorState, Uint8List?>((s) => s.capturedImage) != null;
    final hasRecolored = context.select<RecolorState, Uint8List?>((s) => s.previewImage) != null;

    if (!hasOriginal || !hasRecolored) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isCompareHeld = true),
        onTapUp: (_) => setState(() => _isCompareHeld = false),
        onTapCancel: () => setState(() => _isCompareHeld = false),
        onLongPressStart: (_) => setState(() => _isCompareHeld = true),
        onLongPressEnd: (_) => setState(() => _isCompareHeld = false),
        child: Container(
          decoration: BoxDecoration(
            color: _isCompareHeld ? const Color(0xFFFFC107) : const Color(0xFF404040),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: _isCompareHeld ? Colors.white : Colors.grey,
              width: 2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.compare_arrows, color: Colors.white, size: 24),
              const SizedBox(width: 8),
                Text(
                  _isCompareHeld ? _cachedOriginal : _cachedRecolor,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveImage(BuildContext context, Uint8List? imageBytes) async {
    if (imageBytes == null) return;

    try {
      if (Platform.isIOS) {
        final status = await Permission.photosAddOnly.request();
        if (status != PermissionStatus.granted && status != PermissionStatus.limited) {
if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_cachedNoGalleryPermission)),
        );
          }
          return;
        }
      }

      final fileName = 'recolored_${DateTime.now().millisecondsSinceEpoch}.png';
      await Gal.putImageBytes(
        imageBytes,
        name: fileName,
        album: 'Furniture Recoloring',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_cachedPhotoSaved)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$_cachedErrorSaving: $e')),
        );
      }
    }
  }

  Future<void> _shareImage(BuildContext context, Uint8List? imageBytes) async {
    if (imageBytes == null) return;

    try {
      final tempDir = Directory.systemTemp;
      final file = File('${tempDir.path}/recolored_share_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(imageBytes);
      
      final xFile = XFile(file.path);
      await SharePlus.instance.share(
        ShareParams(files: [xFile], text: _cachedShareText),
      );
      
      Future.delayed(const Duration(seconds: 30), () => file.delete());
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$_cachedErrorSending: $e')),
        );
      }
    }
  }
}
