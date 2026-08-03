import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../utils/app_localizations.dart';

class ColorPaletteScreen extends StatefulWidget {
  const ColorPaletteScreen({super.key});

  @override
  State<ColorPaletteScreen> createState() => _ColorPaletteScreenState();
}

class _ColorPaletteScreenState extends State<ColorPaletteScreen> {
  Color? _selectedColor;
  String? _selectedColorName;

  static const _bg = Color(0xFF151412);

  List<_ColorCategory>? _colorCategories;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  @override
  Widget build(BuildContext context) {
    _colorCategories = [
      _ColorCategory(AppLocalizations.tr(context, 'color_categories_red'), [
        const Color(0xFFE53935),
        const Color(0xFFB71C1C),
        const Color(0xFFEF9A9A),
        const Color(0xFFFF5252),
        const Color(0xFFD32F2F),
      ]),
      _ColorCategory(AppLocalizations.tr(context, 'color_categories_orange'), [
        const Color(0xFFFF6D00),
        const Color(0xFFB33E12),
        const Color(0xFFFFC38A),
        const Color(0xFFF08A1E),
        const Color(0xFFFF9800),
      ]),
      _ColorCategory(AppLocalizations.tr(context, 'color_categories_green'), [
        const Color(0xFF4CAF50),
        const Color(0xFF1B5E20),
        const Color(0xFFA5D6A7),
        const Color(0xFF66BB6A),
        const Color(0xFF2E7D32),
      ]),
      _ColorCategory(AppLocalizations.tr(context, 'color_categories_purple'), [
        const Color(0xFF9C27B0),
        const Color(0xFF4A148C),
        const Color(0xFFCE93D8),
        const Color(0xFFAB47BC),
        const Color(0xFF7B1FA2),
      ]),
      _ColorCategory(AppLocalizations.tr(context, 'color_categories_blue'), [
        const Color(0xFF3F51B5),
        const Color(0xFF1A237E),
        const Color(0xFF9FA8DA),
        const Color(0xFF3949AB),
        const Color(0xFF283593),
      ]),
      _ColorCategory(AppLocalizations.tr(context, 'color_categories_brown'), [
        const Color(0xFF795548),
        const Color(0xFF5D4037),
        const Color(0xFF8D6E63),
        const Color(0xFF4E342E),
        const Color(0xFFA1887F),
      ], labels: [
        AppLocalizations.tr(context, 'brown'),
        AppLocalizations.tr(context, 'dark_brown'),
        AppLocalizations.tr(context, 'light_brown'),
        AppLocalizations.tr(context, 'very_dark_brown'),
        AppLocalizations.tr(context, 'muted_brown'),
      ], colorNames: const [
        'brown',
        'dark brown',
        'light brown',
        'very dark brown',
        'muted brown',
      ]),
      _ColorCategory(AppLocalizations.tr(context, 'color_categories_gray'), [
        const Color(0xFF9E9E9E),
        const Color(0xFF757575),
        const Color(0xFFBDBDBD),
        const Color(0xFF616161),
        const Color(0xFFE0E0E0),
      ], colorNames: const [
        'gray',
        'dark gray',
        'light gray',
        'very dark gray',
        'very light gray',
      ]),
      _ColorCategory(AppLocalizations.tr(context, 'color_categories_beige'), [
        const Color(0xFFF5F5DC),
        const Color(0xFFFAEBD7),
        const Color(0xFFF5DEB3),
        const Color(0xFFFFF8DC),
        const Color(0xFFF0E68C),
      ], colorNames: const [
        'beige',
        'antique white',
        'wheat',
        'cornsilk',
        'khaki',
      ]),
      _ColorCategory(AppLocalizations.tr(context, 'color_categories_pink'), [
        const Color(0xFFFFC0CB),
        const Color(0xFFFF69B4),
        const Color(0xFFDB7093),
        const Color(0xFFFFB6C1),
        const Color(0xFFC71585),
      ], colorNames: const [
        'pink',
        'hot pink',
        'pale violet red',
        'light pink',
        'medium violet red',
      ]),
      _ColorCategory(
        AppLocalizations.tr(context, 'color_categories_metal'),
        [
          const Color(0xFFFFD700),
          const Color(0xFFE0E0E0),
          const Color(0xFFD2691E),
          const Color(0xFFC9A66B),
          const Color(0xFF6E7478),
          const Color(0xFFE8ECEF),
          const Color(0xFFCD7F32),
        ],
        labels: [
          AppLocalizations.tr(context, 'gold'),
          AppLocalizations.tr(context, 'silver'),
          AppLocalizations.tr(context, 'bronze'),
          AppLocalizations.tr(context, 'brass'),
          AppLocalizations.tr(context, 'titanium'),
          AppLocalizations.tr(context, 'stainless_steel'),
          AppLocalizations.tr(context, 'copper'),
        ],
        colorNames: const [
          'gold',
          'silver',
          'bronze',
          'brass',
          'titanium',
          'stainless_steel',
          'copper',
        ],
        isMetal: true,
      ),
      _ColorCategory(
        AppLocalizations.tr(context, 'color_categories_black_white'),
        [
          const Color(0xFF000000),
          const Color(0xFFFFFFFF),
        ],
        labels: [
          AppLocalizations.tr(context, 'black'),
          AppLocalizations.tr(context, 'white'),
        ],
        colorNames: const [
          'black',
          'white',
        ],
      ),
    ];
    final halfScreen = MediaQuery.of(context).size.height * 0.5;
    return SizedBox(
      height: halfScreen,
      child: Container(
        decoration: const BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildColorList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Column(
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
        const SizedBox(height: 12),
        Container(
          color: _bg,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
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
                  child: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                ),
              ),
              const Expanded(child: SizedBox()),
              const _PaletteIconInFrame(),
              const Expanded(child: SizedBox()),
              GestureDetector(
                onTap: _selectedColor != null
                    ? () => Navigator.pop(context, {
                          'color': _selectedColor,
                          'colorName': _selectedColorName
                        })
                    : null,
                child: Icon(
                  Icons.check,
                  color: _selectedColor != null ? Colors.white : Colors.white38,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildColorList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        ...List.generate(_colorCategories!.length, (index) {
          final category = _colorCategories![index];
          final isMetal = category.isMetal;
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 10),
                  child: Text(
                    category.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: List.generate(category.shades.length, (i) {
                    final originalColor = category.shades[i];
                    final label = (category.labels != null && i < category.labels!.length)
                        ? category.labels![i]
                        : null;
                    final colorName = (category.colorNames != null &&
                            i < category.colorNames!.length)
                        ? category.colorNames![i]
                        : null;
                    final isSelected = _selectedColor == originalColor;
                    return _ColorCircle(
                      color: originalColor,
                      label: label,
                      isMetal: isMetal,
                      isSelected: isSelected,
                      onTap: () {
                        setState(() {
                          _selectedColor = originalColor;
                          _selectedColorName = colorName;
                        });
                      },
                    );
                  }),
                ),
                if (isMetal) const _PatinaToggle(),
              ],
            ),
          );
        }),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _PatinaToggle extends StatelessWidget {
  const _PatinaToggle();

  @override
  Widget build(BuildContext context) {
    final patinaMode = context.select<AppState, bool>((s) => s.patinaMode);
    return Padding(
      padding: const EdgeInsets.only(top: 14, left: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(
            value: patinaMode,
            onChanged: (value) {
              context.read<AppState>().setPatinaMode(value);
            },
          ),
          Text(
            AppLocalizations.tr(context, 'aging'),
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorCircle extends StatelessWidget {
  final Color color;
  final String? label;
  final bool isMetal;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorCircle({
    required this.color,
    this.label,
    this.isMetal = false,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final patinaMode = context.select<AppState, bool>((s) => s.patinaMode);
    var displayColor = color;
    if (isMetal && patinaMode) {
      displayColor = _applyPatinaWash(color);
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: displayColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white24,
            width: isSelected ? 3 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (isMetal)
              Opacity(
                opacity: 0.4,
                child: ColorFiltered(
                  colorFilter: const ColorFilter.matrix(<double>[
                    0.2126, 0.7152, 0.0722, 0, 0,
                    0.2126, 0.7152, 0.0722, 0, 0,
                    0.2126, 0.7152, 0.0722, 0, 0,
                    0, 0, 0, 1, 0,
                  ]),
                  child: Image.asset(
                    'assets/textures/metal_texture.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            if (label != null)
              Center(
                child: Text(
                  label!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    shadows: [
                      Shadow(
                        color: Colors.black87,
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            if (isSelected)
              const Center(
                child: Icon(Icons.check, color: Colors.white, size: 22),
              ),
          ],
        ),
      ),
    );
  }
}

Color _applyPatinaWash(Color color) {
  final hsl = HSLColor.fromColor(color);
  return hsl.withLightness((hsl.lightness + 0.2).clamp(0.0, 1.0)).toColor();
}

class _ColorCategory {
  final String name;
  final List<Color> shades;
  final List<String>? labels;
  final List<String>? colorNames;
  final bool isMetal;

  _ColorCategory(this.name, this.shades, {this.labels, this.colorNames, this.isMetal = false});
}

class _PaletteIconInFrame extends StatelessWidget {
  const _PaletteIconInFrame();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/icons/ramka.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Center(
        child: Image.asset(
          'assets/icons/Paint Palette.png',
          width: 24,
          height: 24,
          color: Colors.white,
        ),
      ),
    );
  }
}
