import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/selection_tool.dart';

class SelectionState extends ChangeNotifier {
  Uint8List _selectionMask = Uint8List(0);
  Uint8List get selectionMask => _selectionMask;

  SelectionTool _currentTool = SelectionTool.brush;
  SelectionTool get currentTool => _currentTool;

  double _brushSize = 30.0;
  double get brushSize => _brushSize;

  final List<Uint8List> _maskHistory = [];
  int _historyIndex = -1;

  Color _selectedColor = const Color(0xFF8B4513);
  Color get selectedColor => _selectedColor;

  String? _selectedColorName;
  String? get selectedColorName => _selectedColorName;

  bool _isColorFromPipette = false;
  bool get isColorFromPipette => _isColorFromPipette;

  bool canUndo() => _historyIndex > 0;

  bool canRedo() => _historyIndex < _maskHistory.length - 1;

  void setSelectionMask(Uint8List mask) {
    _selectionMask = mask;
    notifyListeners();

    _saveToHistory(mask);
  }

  void _saveToHistory(Uint8List mask) {
    if (_historyIndex < _maskHistory.length - 1) {
      _maskHistory.removeRange(_historyIndex + 1, _maskHistory.length);
    }
    if (mask.isNotEmpty) {
      _maskHistory.add(Uint8List.fromList(mask));
    } else {
      _maskHistory.add(Uint8List(0));
    }
    _historyIndex = _maskHistory.length - 1;
    const maxHistory = 10;
    while (_maskHistory.length > maxHistory) {
      _maskHistory.removeAt(0);
      _historyIndex--;
    }
  }

  void undo() {
    if (canUndo()) {
      _historyIndex--;
      _selectionMask = Uint8List.fromList(_maskHistory[_historyIndex]);
      notifyListeners();
    }
  }

  void redo() {
    if (canRedo()) {
      _historyIndex++;
      _selectionMask = Uint8List.fromList(_maskHistory[_historyIndex]);
      notifyListeners();
    }
  }

  void setCurrentTool(SelectionTool tool) {
    _currentTool = tool;
    notifyListeners();
  }

  void setBrushSize(double size) {
    _brushSize = size;
    notifyListeners();
  }

  void setSelectedColor(Color color) {
    _selectedColor = color;
    notifyListeners();
  }

  void setSelectedColorName(String? colorName, {bool fromPipette = false}) {
    _selectedColorName = colorName;
    _isColorFromPipette = fromPipette;
    notifyListeners();
  }

  void clearSelectedColor() {
    _isColorFromPipette = false;
    notifyListeners();
  }

  void resetSelection() {
    _selectionMask = Uint8List(0);
    _maskHistory.clear();
    _historyIndex = -1;
    notifyListeners();
  }
}
