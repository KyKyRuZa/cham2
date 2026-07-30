import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../utils/app_localizations.dart';

class MaterialSelectionScreen extends StatefulWidget {
  const MaterialSelectionScreen({super.key});

  @override
  State<MaterialSelectionScreen> createState() => _MaterialSelectionScreenState();
}

class _MaterialSelectionScreenState extends State<MaterialSelectionScreen> {
  String _selectedMaterial = '';
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _selectedMaterial = 'wood';
  }

  static const _bg = Color(0xFF151412);
  static const _surface = Color(0xFF151412);
  static const _accent = Color(0xFFFFC107);
  static const _textPrimary = Colors.white;
  static const _textSecondary = Colors.white70;
  static const _border = Colors.white12;

  Map<String, String> _materialLabels = {};

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      _selectedMaterial = context.select<AppState, String>((s) => s.selectedMaterial);
      _initialized = true;
    }
    _materialLabels = {
      'wood': AppLocalizations.tr(context, 'wood'),
      'metal': AppLocalizations.tr(context, 'metal'),
      'plastic': AppLocalizations.tr(context, 'plastic'),
      'fabric': AppLocalizations.tr(context, 'fabric'),
      'glass': AppLocalizations.tr(context, 'glass'),
      'leather': AppLocalizations.tr(context, 'leather'),
      'ceramic': AppLocalizations.tr(context, 'ceramic'),
      'concrete': AppLocalizations.tr(context, 'concrete'),
      'no_texture': AppLocalizations.tr(context, 'no_texture'),
    };
    return Container(
      decoration: const BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            _buildTopBar(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    _buildMaterialGrid(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Colors.white12,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back, color: _textPrimary, size: 22),
            ),
          ),
          Text(
            AppLocalizations.tr(context, 'material_selection'),
            style: TextStyle(
              color: _textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          GestureDetector(
            onTap: () {
              final appState = context.read<AppState>();
              appState.setSelectedMaterial(_selectedMaterial);
              // Сбрасываем текстуры если выбран не wood/metal/no_texture
              if (_selectedMaterial != 'wood' && _selectedMaterial != 'no_texture') {
                appState.setSelectedWoodTexture(null);
              }
              if (_selectedMaterial != 'metal' && _selectedMaterial != 'no_texture') {
                appState.setSelectedMetalTexture(null);
              }
              // Для no_texture сбрасываем все текстуры
              if (_selectedMaterial == 'no_texture') {
                appState.setSelectedWoodTexture(null);
                appState.setSelectedMetalTexture(null);
              }
              Navigator.pop(context, _selectedMaterial);
            },
            child: const Icon(
              Icons.check,
              color: _textPrimary,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialGrid() {
    final materials = _materialLabels.keys.toList();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 3.2,
      ),
      itemCount: materials.length,
      itemBuilder: (context, index) {
        final material = materials[index];
        final isSelected = _selectedMaterial == material;
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedMaterial = material;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected ? _accent : _surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? _textPrimary : _border,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _materialIcon(material),
                  color: isSelected ? Colors.black : _textSecondary,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  _materialLabels[material]!,
                  style: TextStyle(
                    color: isSelected ? Colors.black : _textSecondary,
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _materialIcon(String material) {
    switch (material) {
      case 'wood':
        return Icons.table_chart;
      case 'metal':
        return Icons.auto_awesome_mosaic;
      case 'plastic':
        return Icons.opacity_outlined;
      case 'fabric':
        return Icons.grid_view;
      case 'glass':
        return Icons.visibility;
      case 'leather':
        return Icons.style;
      case 'ceramic':
        return Icons.water_drop;
      case 'concrete':
        return Icons.grain;
      case 'no_texture':
        return Icons.opacity;
      default:
        return Icons.category_outlined;
    }
  }
}