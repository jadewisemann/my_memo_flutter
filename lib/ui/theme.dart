import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Premium dark theme for the MyMemo outliner.
class AppTheme {
  AppTheme._();

  // ─── Color Palette ───────────────────────────────────────────────
  static const Color _bgPrimary = Color(0xFF0D1117);
  static const Color _bgSecondary = Color(0xFF161B22);
  static const Color _bgTertiary = Color(0xFF1C2128);
  static const Color _bgHover = Color(0xFF1F2937);
  static const Color _bgNodeFocused = Color(0xFF1A2332);

  static const Color _textPrimary = Color(0xFFE6EDF3);
  static const Color _textSecondary = Color(0xFF8B949E);
  static const Color _textMuted = Color(0xFF484F58);

  static const Color _accentPrimary = Color(0xFF58A6FF);
  static const Color _accentSecondary = Color(0xFF3FB950);
  static const Color _accentWarm = Color(0xFFF78166);

  static const Color _borderSubtle = Color(0xFF21262D);
  static const Color _borderFocus = Color(0xFF388BFD);

  // ─── Getters for use in widgets ──────────────────────────────────
  static Color get bgPrimary => _bgPrimary;
  static Color get bgSecondary => _bgSecondary;
  static Color get bgTertiary => _bgTertiary;
  static Color get bgHover => _bgHover;
  static Color get bgNodeFocused => _bgNodeFocused;
  static Color get textPrimary => _textPrimary;
  static Color get textSecondary => _textSecondary;
  static Color get textMuted => _textMuted;
  static Color get accentPrimary => _accentPrimary;
  static Color get accentSecondary => _accentSecondary;
  static Color get accentWarm => _accentWarm;
  static Color get borderSubtle => _borderSubtle;
  static Color get borderFocus => _borderFocus;

  // ─── Theme Data ──────────────────────────────────────────────────
  static ThemeData get darkTheme {
    final baseTextTheme = GoogleFonts.interTextTheme(
      ThemeData.dark().textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _bgPrimary,
      colorScheme: const ColorScheme.dark(
        surface: _bgPrimary,
        primary: _accentPrimary,
        secondary: _accentSecondary,
        tertiary: _accentWarm,
        onSurface: _textPrimary,
        onPrimary: _bgPrimary,
        outline: _borderSubtle,
      ),
      textTheme: baseTextTheme.copyWith(
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(
          color: _textPrimary,
          fontSize: 15,
          height: 1.6,
        ),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(
          color: _textSecondary,
          fontSize: 14,
        ),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          color: _textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: _bgSecondary,
        foregroundColor: _textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: _textPrimary,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: _borderSubtle,
        thickness: 1,
      ),
      iconTheme: const IconThemeData(
        color: _textSecondary,
        size: 18,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return _accentPrimary;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(_bgPrimary),
        side: const BorderSide(color: _textMuted, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}
