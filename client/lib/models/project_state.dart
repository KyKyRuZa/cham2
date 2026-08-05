import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../utils/logger.dart';

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

class ProjectState extends ChangeNotifier {
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
      AppLog.e('ProjectState initialize error: $e');
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
      AppLog.e('Error loading projects: $e');
    }
  }

  Future<void> _saveProjectToFile(Uint8List imageBytes, int id) async {
    if (_projectsDir == null) return;
    try {
      final file = File(p.join(_projectsDir!.path, '$id.png'));
      await file.writeAsBytes(imageBytes);
    } catch (e) {
      AppLog.e('Error saving project: $e');
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
      AppLog.e('Error deleting project: $e');
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

  /// Replaces the image bytes of the most recently added project (index 0)
  /// and rewrites its file, keeping the same id.
  void updateMostRecentProject(Uint8List imageBytes) {
    if (_projects.isEmpty) {
      addProject(imageBytes);
      return;
    }
    final project = _projects.first;
    _projects[0] = project.copyWith(imageBytes: imageBytes);
    _saveProjectToFile(imageBytes, project.id);
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
}
