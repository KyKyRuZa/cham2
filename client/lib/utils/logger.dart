import 'dart:developer' as developer;

class AppLog {
  static void d(String message, [String? tag]) {
    final name = tag != null ? '[$tag] $message' : message;
    developer.log(name, level: 500, name: tag ?? 'App');
  }

  static void i(String message, [String? tag]) {
    final name = tag != null ? '[$tag] $message' : message;
    developer.log(name, level: 800, name: tag ?? 'App');
  }

  static void w(String message, [String? tag]) {
    final name = tag != null ? '[$tag] $message' : message;
    developer.log(name, level: 900, name: tag ?? 'App');
  }

  static void e(String message, [String? tag]) {
    final name = tag != null ? '[$tag] $message' : message;
    developer.log(name, level: 1000, name: tag ?? 'App');
  }
}
