import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'models/app_state.dart';
import 'screens/camera_page.dart';
import 'screens/projects_screen.dart';
import 'screens/editor_screen.dart';
import 'screens/color_picker_screen.dart';
import 'screens/color_palette_screen.dart';
import 'screens/export_screen.dart';
import 'screens/settings_screen.dart';
import 'utils/transitions.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Загружаем переменные окружения (.env). Если файл отсутствует —
  // приложение продолжит работу со значениями по умолчанию.
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('Не удалось загрузить .env: $e');
  }
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  runApp(
    ChangeNotifierProvider(
      create: (context) => AppState()..initialize(),
      child: const FurnitureRecoloringApp(),
    ),
  );
}

/// Main application widget for furniture recoloring
class FurnitureRecoloringApp extends StatelessWidget {
  const FurnitureRecoloringApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const _AppMaterialApp();
  }
}

/// Extracted MaterialApp — separated from ChangeNotifierProvider so that
/// theme/routes are never rebuilt when AppState notifies listeners.
class _AppMaterialApp extends StatelessWidget {
  const _AppMaterialApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Recolor App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF151412),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFF5C518),
          secondary: Color(0xFF3A3A3C),
          surface: Color(0xFF151412),
          onPrimary: Colors.black,
          onSecondary: Colors.white,
          onSurface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF151412),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF151412),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          elevation: 2,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF5C518),
            foregroundColor: Colors.black,
            elevation: 3,
            shadowColor: const Color(0xFFF5C518).withValues(alpha: 0.3),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        textButtonTheme: const TextButtonThemeData(
          style: ButtonStyle(
            foregroundColor: WidgetStatePropertyAll(Color(0xFFF5C518)),
            textStyle: WidgetStatePropertyAll(
              TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFF151412),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: Color(0xFFF5C518), width: 2),
          ),
        ),
      ),
      home: const CameraPage(),
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/projects':
            return AppTransitions.staggeredSlideRoute(
              const ProjectsScreen(),
              direction: SlideDirection.left,
            );
          case '/editor':
            return AppTransitions.rotateScaleRoute(const EditorScreen());
case '/color_picker':
             return AppTransitions.scaleRoute(
               ColorPickerScreen(
                 initialColor: const Color(0xFF8B4513),
                 onColorChanged: (color) {},
               ),
             );
          case '/color_palette':
            return AppTransitions.slideRoute(
              const ColorPaletteScreen(),
              direction: SlideDirection.up,
              curve: Curves.easeOutBack,
            );
          case '/export':
            return AppTransitions.slideRoute(
              const ExportScreen(),
              direction: SlideDirection.up,
              curve: Curves.easeOutCubic,
            );
          case '/settings':
            return AppTransitions.slideRoute(
              const SettingsScreen(),
              direction: SlideDirection.left,
            );
          default:
            return AppTransitions.fadeRoute(
              const CameraPage(),
              withScale: true,
            );
        }
      },
    );
  }
}
