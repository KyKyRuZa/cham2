import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'selection_tool.dart';
import 'dart:async';
import '../utils/app_localizations.dart';

/// Represents a saved project (edited photo) — immutable model
@immutable
class Project {
  final int id;
  final Uint8List imageBytes;
  final bool liked;
  final DateTime createdAt;

  Project({required this.imageBytes, int? id, this.liked = false, DateTime? createdAt})
    : id = id ?? DateTime.now().millisecondsSinceEpoch,
      createdAt = createdAt ?? DateTime.now();

  Project copyWith({Uint8List? imageBytes, bool? liked, DateTime? createdAt}) {
    return Project(
      imageBytes: imageBytes ?? this.imageBytes,
      liked: liked ?? this.liked,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Application state model
class AppState extends ChangeNotifier {
  // Current stage of the application
  AppStage _currentStage = AppStage.camera;
  AppStage get currentStage => _currentStage;

  // App locale
  AppLocale _locale = AppLocale.russian;
  AppLocale get locale => _locale;

  void toggleLocale() {
    _locale = _locale == AppLocale.russian ? AppLocale.english : AppLocale.russian;
    notifyListeners();
  }

  // Captured image
  Uint8List? _capturedImage;
  Uint8List? get capturedImage => _capturedImage;

  // Selection mask (1 = selected, 0 = not selected)
  Uint8List _selectionMask = Uint8List(0);
  Uint8List get selectionMask => _selectionMask;

  // Undo/Redo history for selection mask
  final List<Uint8List> _maskHistory = [];
  int _historyIndex = -1;

  // Current selection tool
  SelectionTool _currentTool = SelectionTool.brush;
  SelectionTool get currentTool => _currentTool;

  // Selected color for recoloring
  Color _selectedColor = const Color(0xFF8B4513); // Default wood brown
  Color get selectedColor => _selectedColor;

  String? _selectedColorName;
  String? get selectedColorName => _selectedColorName;

  bool _isColorFromPipette = false;
  bool get isColorFromPipette => _isColorFromPipette;

  void setSelectedColorName(String? colorName, {bool fromPipette = false}) {
    _selectedColorName = colorName;
    _isColorFromPipette = fromPipette;
    notifyListeners();
  }

  void clearSelectedColor() {
    _isColorFromPipette = false;
    notifyListeners();
  }

  // Selected wood texture (for tree color selection)
  String?
  _selectedWoodTexture; // 'wood1', 'wood2', 'wood3', or null for no texture
  String? get selectedWoodTexture => _selectedWoodTexture;

  void setSelectedWoodTexture(String? texture) {
    _selectedWoodTexture = texture;
    notifyListeners();
  }

  // Selected metal texture (for metal color selection)
  String?
  _selectedMetalTexture; // 'metall1', 'metall2', 'metall3', or null for no texture
  String? get selectedMetalTexture => _selectedMetalTexture;

  void setSelectedMetalTexture(String? texture) {
    _selectedMetalTexture = texture;
    notifyListeners();
  }

  // Aging (patina) mode for metal recoloring
  bool _patinaMode = false;
  bool get patinaMode => _patinaMode;

  void setPatinaMode(bool value) {
    _patinaMode = value;
    notifyListeners();
  }

  // Preview mode
  bool _isPreviewMode = false;
  bool get isPreviewMode => _isPreviewMode;

  // Preview recolored image
  Uint8List? _previewImage;
  Uint8List? get previewImage => _previewImage;

  // Brush size for selection
  double _brushSize = 30.0;
  double get brushSize => _brushSize;

  // Loading state
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // Error message
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // My palette (max 8 colors)
  final List<Color> _myPaletteColors = [];
  List<Color> get myPaletteColors => List.unmodifiable(_myPaletteColors);
  static const int maxPaletteSlots = 8;

  void addToMyPalette(Color color) {
    if (_myPaletteColors.length < maxPaletteSlots) {
      _myPaletteColors.add(color);
      notifyListeners();
    }
  }

  void removeFromMyPalette(int index) {
    if (index >= 0 && index < _myPaletteColors.length) {
      _myPaletteColors.removeAt(index);
      notifyListeners();
    }
  }

  void clearMyPalette() {
    _myPaletteColors.clear();
    notifyListeners();
  }

  // Selected material type for recoloring
  String _selectedMaterial = 'wood';
  String get selectedMaterial => _selectedMaterial;

void setSelectedMaterial(String material) {
    _selectedMaterial = material;
    notifyListeners();
  }

  String? getSelectedTexture() {
    if (_selectedMaterial == 'wood') {
      return _selectedWoodTexture;
    } else if (_selectedMaterial == 'metal') {
      return _selectedMetalTexture;
    }
    // Для остальных материалов и no_texture возвращаем пустую строку (без текстуры)
    return '';
  }

  final Uint8List _emptyMask = Uint8List(0);
  Timer? _debounce;
  static const Duration _debounceDuration = Duration(milliseconds: 300);

  // Projects history
  final List<Project> _projects = [];
  List<Project> get projects => List.unmodifiable(_projects);
  Directory? _projectsDir;

  Future<void> initialize() async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      _projectsDir = Directory(p.join(appDocDir.path, 'projects'));
      await _projectsDir!.create(recursive: true);
      await _loadProjects();
    } catch (e) {
      debugPrint('AppState initialize error: $e');
    }
  }

  Future<void> _loadProjects() async {
    if (_projectsDir == null) return;
    try {
      final files = _projectsDir!
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.png'))
          .toList();
      files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      _projects
        ..clear()
        ..addAll(files.map((f) {
          final id = int.tryParse(p.basenameWithoutExtension(f.path)) ?? DateTime.now().millisecondsSinceEpoch;
          return Project(
            imageBytes: f.readAsBytesSync(),
            id: id,
            createdAt: f.lastModifiedSync(),
          );
        }).toList());
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading projects: $e');
    }
  }

  Future<void> _saveProjectToFile(Uint8List imageBytes, int id) async {
    if (_projectsDir == null) return;
    try {
      final file = File(p.join(_projectsDir!.path, '$id.png'));
      await file.writeAsBytes(imageBytes);
    } catch (e) {
      debugPrint('Error saving project: $e');
    }
  }

  Future<void> _deleteProjectFile(int id) async {
    if (_projectsDir == null) return;
    try {
      final file = File(p.join(_projectsDir!.path, '$id.png'));
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error deleting project file: $e');
    }
  }

  List<Project> get sortedProjects {
    final sorted = List<Project>.from(_projects);
    sorted.sort((a, b) {
      if (a.liked && !b.liked) return -1;
      if (!a.liked && b.liked) return 1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return List.unmodifiable(sorted);
  }

  void addProject(Uint8List imageBytes) {
    final id = DateTime.now().millisecondsSinceEpoch;
    final project = Project(imageBytes: imageBytes, id: id);
    _projects.insert(0, project);
    _saveProjectToFile(imageBytes, id);
    notifyListeners();
  }

  void deleteProject(int projectId) {
    final index = _projects.indexWhere((p) => p.id == projectId);
    if (index != -1) {
      _deleteProjectFile(projectId);
      _projects.removeAt(index);
      notifyListeners();
    }
  }

  void toggleProjectLike(int projectId) {
    final index = _projects.indexWhere((p) => p.id == projectId);
    if (index == -1) return;
    _projects[index] = _projects[index].copyWith(
      liked: !_projects[index].liked,
    );
    notifyListeners();
  }

  /// Update stage
  void setStage(AppStage stage) {
    _currentStage = stage;
    notifyListeners();
  }

  /// Set captured image
  void setCapturedImage(Uint8List? image) {
    _capturedImage = image;
    _selectionMask = Uint8List(0);
    _previewImage = null;
    _isPreviewMode = false;
    // Reset history and save initial empty state
    _maskHistory.clear();
    _historyIndex = -1;
    if (image != null) {
      // Save initial empty mask so we can undo the first action
      _saveToHistory(Uint8List(0));
    }
    notifyListeners();
  }

  /// Set selection mask
  void setSelectionMask(Uint8List mask) {
    _selectionMask = mask;
    _previewImage = null;
    notifyListeners();

    // Debounce history saving
    if (_debounce != null && _debounce!.isActive) {
      _debounce!.cancel();
    }
    _debounce = Timer(_debounceDuration, () {
      _saveToHistory(mask);
    });

    // Логируем базовую статистику выделения
    final selectedCount = mask.where((p) => p == 1).length;
    // ignore: avoid_print
    if (selectedCount > 0) {
      print('[Selection] Маска обновлена: выделено $selectedCount пикселей');
      // ignore: avoid_print
      print(
        '  (Для классификации по яркости нажмите "Превью" или завершите выделение)',
      );
    }
  }

  /// Save current mask to history
  void _saveToHistory(Uint8List mask) {
    // Remove any redo states
    if (_historyIndex < _maskHistory.length - 1) {
      _maskHistory.removeRange(_historyIndex + 1, _maskHistory.length);
    }
    // Add new state (make a copy only if mask is non-empty)
    if (mask.isNotEmpty) {
      _maskHistory.add(Uint8List.fromList(mask));
    } else {
      _maskHistory.add(Uint8List(0));
    }
    _historyIndex = _maskHistory.length - 1;
     // Limit history size to prevent memory bloat
     const maxHistory = 20;
     while (_maskHistory.length > maxHistory) {
      _maskHistory.removeAt(0);
      _historyIndex--;
    }
  }

  /// Undo last selection change
  bool canUndo() => _historyIndex > 0;

  void undo() {
    if (canUndo()) {
      _historyIndex--;
      _selectionMask = Uint8List.fromList(_maskHistory[_historyIndex]);
      _previewImage = null;
      notifyListeners();
    }
  }

  /// Redo last undone change
  bool canRedo() => _historyIndex < _maskHistory.length - 1;

  void redo() {
    if (canRedo()) {
      _historyIndex++;
      _selectionMask = Uint8List.fromList(_maskHistory[_historyIndex]);
      _previewImage = null;
      notifyListeners();
    }
  }

  /// Set current tool
  void setCurrentTool(SelectionTool tool) {
    _currentTool = tool;
    notifyListeners();
  }

  /// Set selected color
  void setSelectedColor(Color color) {
    _selectedColor = color;
    _previewImage = null;
    notifyListeners();
  }

  /// Toggle preview mode
  void togglePreviewMode() {
    _isPreviewMode = !_isPreviewMode;
    notifyListeners();
  }

  /// Set preview image
  void setPreviewImage(Uint8List? image) {
    _previewImage = image;
    notifyListeners();
  }

  /// Set brush size
  void setBrushSize(double size) {
    _brushSize = size;
    notifyListeners();
  }

  /// Set loading state
  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Set error message
  void setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Reset selection
  void resetSelection() {
    setSelectionMask(Uint8List(0));
  }

  /// Clear all (reset to beginning)
  void clearAll() {
_capturedImage = null;
    _selectionMask = Uint8List(0);
    _previewImage = null;
    _currentStage = AppStage.camera;
    _isPreviewMode = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _projectsDir = null;
    super.dispose();
  }
}

/// Application stages
enum AppStage {
  /// Camera capture stage
  camera,

  /// Image editor stage
  editor,

  /// Color picker stage
  colorPicker,
}
