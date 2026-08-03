import 'package:flutter/material.dart';

enum AppLocale { russian, english }

class SettingsState extends ChangeNotifier {
  AppLocale _locale = AppLocale.russian;
  AppLocale get locale => _locale;

  bool _isPreviewMode = false;
  bool get isPreviewMode => _isPreviewMode;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _patinaMode = false;
  bool get patinaMode => _patinaMode;

  String? _selectedWoodTexture;
  String? get selectedWoodTexture => _selectedWoodTexture;

  String? _selectedMetalTexture;
  String? get selectedMetalTexture => _selectedMetalTexture;

  String _selectedMaterial = 'wood';
  String get selectedMaterial => _selectedMaterial;

  void setSelectedMaterial(String material) {
    _selectedMaterial = material;
    notifyListeners();
  }

  void toggleLocale() {
    _locale = _locale == AppLocale.russian ? AppLocale.english : AppLocale.russian;
    notifyListeners();
  }

  void togglePreviewMode() {
    _isPreviewMode = !_isPreviewMode;
    notifyListeners();
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void setPatinaMode(bool value) {
    _patinaMode = value;
    notifyListeners();
  }

  void setSelectedWoodTexture(String? texture) {
    _selectedWoodTexture = texture;
    notifyListeners();
  }

  void setSelectedMetalTexture(String? texture) {
    _selectedMetalTexture = texture;
    notifyListeners();
  }
}
