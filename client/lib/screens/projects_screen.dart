import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kDebugMode;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../models/project_state.dart';
import '../models/recolor_state.dart';
import '../utils/app_localizations.dart';
import '../utils/image_utils.dart';
import '../utils/transitions.dart';
import 'camera_page.dart';
import 'export_screen.dart';
import 'editor_screen.dart';
import 'settings_screen.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0E0A),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.3),
                radius: 1.2,
                colors: [Color(0xFF3D1F10), Color(0xFF1A0E0A)],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      SizedBox(width: 38, height: 38),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocalizations.tr(context, 'your_projects'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              AppLocalizations.tr(
                                context,
                                'your_items_for_recoloring',
                              ),
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _circleIconBtn(
                        'assets/icons/setings.png',
                        onTap: () {
                          Navigator.push(
                            context,
                            AppTransitions.slideRoute(
                              const SettingsScreen(),
                              direction: SlideDirection.left,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Projects grid
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Consumer<ProjectState>(
                      builder: (context, projectState, child) {
                        final projects = projectState.sortedProjects;
                        if (projects.isEmpty) {
                          return Center(
                            child: Text(
                              AppLocalizations.tr(context, 'no_projects'),
                              style: TextStyle(color: Colors.white54),
                            ),
                          );
                        }
                        return GridView.builder(
                          itemCount: projects.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                childAspectRatio: 0.85,
                              ),
                          itemBuilder: (context, index) {
                            final project = projects[index];
                            return GestureDetector(
                              onTap: () {
                                final recolorState = context
                                    .read<RecolorState>();
                                recolorState.setCapturedImage(
                                  project.imageBytes,
                                );
                                Navigator.push(
                                  context,
                                  AppTransitions.slideRoute(
                                    ExportScreen(
                                      initialImageBytes: project.imageBytes,
                                    ),
                                    direction: SlideDirection.left,
                                  ),
                                );
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.memory(
                                      project.imageBytes,
                                      fit: BoxFit.cover,
                                    ),
                                    // Like button
                                    Positioned(
                                      top: 8,
                                      left: 8,
                                      child: GestureDetector(
                                        onTap: () => projectState
                                            .toggleProjectLike(project.id),
                                        child: Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: project.liked
                                                ? Colors.red
                                                : Colors.black38,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.all(7),
                                            child: Image.asset(
                                              'assets/icons/favorite.png',
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Delete button - always visible
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: GestureDetector(
                                        onTap: () => projectState.deleteProject(
                                          project.id,
                                        ),
                                        child: Container(
                                          width: 32,
                                          height: 32,
                                          decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.delete,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
                // Bottom buttons
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (defaultTargetPlatform == TargetPlatform.iOS) {
                              _openNativeCamera();
                            } else {
                              Provider.of<RecolorState>(
                                context,
                                listen: false,
                              ).setStage(AppStage.camera);
                              Navigator.push(
                                context,
                                AppTransitions.slideRoute(
                                  const CameraPage(),
                                  direction: SlideDirection.left,
                                ),
                              );
                            }
                          },
                          child: Container(
                            height: 54,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5C518),
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: Center(
                              child: Text(
                                AppLocalizations.tr(context, 'take_photo'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: _pickFromGallery,
                        child: Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Image.asset(
                              'assets/icons/Add_Image.png',
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openNativeCamera() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;

    final navigatorContext = context;
    PermissionStatus cameraStatus = await Permission.camera.request();
    if (!cameraStatus.isGranted) {
      if (navigatorContext.mounted) {
        ScaffoldMessenger.of(navigatorContext).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.tr(
                navigatorContext,
                'camera_requires_permission',
              ),
            ),
          ),
        );
      }
      return;
    }

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        imageQuality: 100,
      );

      if (!mounted || image == null) return;

      final bytes = await image.readAsBytes();
      if (kDebugMode) debugPrint('Native camera image: ${bytes.length} bytes');

      if (!mounted) return;
      final normalizedBytes = normalizeImageBytes(bytes);
      if (navigatorContext.mounted) {
        navigatorContext.read<RecolorState>().setCapturedImage(normalizedBytes);
      }
      if (navigatorContext.mounted) {
        Navigator.push(
          navigatorContext,
          AppTransitions.slideRoute(
            const EditorScreen(),
            direction: SlideDirection.left,
            duration: const Duration(milliseconds: 120),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error opening native camera: $e');
      if (navigatorContext.mounted) {
        ScaffoldMessenger.of(navigatorContext).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.tr(navigatorContext, 'camera_error')}: $e',
            ),
          ),
        );
      }
    }
  }

  Future<void> _pickFromGallery() async {
    // Request storage/photos permission with Android 13+ support
    PermissionStatus status;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      status = await Permission.photos.request();
    } else {
      // Android: try photos permission first (Android 13+), fallback to storage
      try {
        status = await Permission.photos.request();
        if (!status.isGranted) {
          status = await Permission.storage.request();
        }
      } catch (e) {
        // If Permission.photos not supported (Android <13), use storage
        status = await Permission.storage.request();
      }
    }
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.tr(context, 'gallery_permission_required'),
            ),
          ),
        );
      }
      return;
    }

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        imageQuality: 100,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        if (kDebugMode) {
          debugPrint('Picked image from gallery: ${bytes.length} bytes');
        }

        if (mounted) {
          final normalizedBytes = normalizeImageBytes(bytes);
          context.read<RecolorState>().setCapturedImage(normalizedBytes);
          Navigator.push(
            context,
            AppTransitions.slideRoute(
              const EditorScreen(),
              direction: SlideDirection.left,
              duration: const Duration(milliseconds: 120),
            ),
          );
        }
      } else {
        if (kDebugMode) debugPrint('No image selected from gallery');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.tr(context, 'error_selecting_image')}: $e',
            ),
          ),
        );
      }
    }
  }

  Widget _circleIconBtn(String asset, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: const BoxDecoration(
          color: Colors.white12,
          shape: BoxShape.circle,
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Image.asset(asset, color: Colors.white),
        ),
      ),
    );
  }
}
