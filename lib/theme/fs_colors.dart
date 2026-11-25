import 'package:material_ui/material_ui.dart';

/// Colours chosen to sit close to the 3CX Windows softphone:
/// a dark navigation rail, a light workspace, and a green call action.
abstract final class FsColors {
  static const Color nav = Color(0xFF1B2431);
  static const Color navHover = Color(0xFF2A3548);
  static const Color navActive = Color(0xFF314158);
  static const Color accent = Color(0xFF1F6FEB);
  static const Color call = Color(0xFF1FA855);
  static const Color hangup = Color(0xFFE23B3B);
  static const Color canvas = Color(0xFFF3F5F8);
  static const Color card = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF1B2431);
  static const Color muted = Color(0xFF667085);
  static const Color line = Color(0xFFE4E8EE);
  static const Color missed = Color(0xFFD92D20);
  static const Color away = Color(0xFFF5A524);
  static const Color available = Color(0xFF17B26A);
}

ThemeData buildFsTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: FsColors.accent,
    primary: FsColors.accent,
    surface: FsColors.card,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: FsColors.canvas,
    dividerColor: FsColors.line,
    splashFactory: InkRipple.splashFactory,
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: FsColors.ink, fontSize: 14),
      bodySmall: TextStyle(color: FsColors.muted, fontSize: 12),
      titleLarge: TextStyle(
        color: FsColors.ink,
        fontSize: 22,
        fontWeight: FontWeight.w600,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF7F8FA),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: FsColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: FsColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: FsColors.accent, width: 1.6),
      ),
      labelStyle: const TextStyle(color: FsColors.muted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: FsColors.accent,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    cardTheme: CardThemeData(
      color: FsColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: FsColors.line),
      ),
    ),
  );
}
