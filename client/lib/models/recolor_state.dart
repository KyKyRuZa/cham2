import 'dart:typed_data';
import 'package:flutter/material.dart';

enum AppStage { camera, editor, colorPicker }

class RecolorState extends ChangeNotifier {
  AppStage _currentStage = AppStage.camera;
  AppStage get currentStage => _currentStage;

  Uint8List? _capturedImage;
  Uint8List? get capturedImage => _capturedImage;

  Uint8List? _previewImage;
  Uint8List? get previewImage => _previewImage;

  void setStage(AppStage stage) {
    _currentStage = stage;
    notifyListeners();
  }

  void setCapturedImage(Uint8List? image) {
    _capturedImage = image;
    _previewImage = null;
    notifyListeners();
  }

  void setPreviewImage(Uint8List? image) {
    _previewImage = image;
    notifyListeners();
  }

  void clearAll() {
    _capturedImage = null;
    _previewImage = null;
    _currentStage = AppStage.camera;
    notifyListeners();
  }
}
