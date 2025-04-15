import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentinel/core/utils/settings_service.dart';

/// Provider for the current accent color index
final accentColorProvider = StateNotifierProvider<AccentColorNotifier, int>(
  (ref) => AccentColorNotifier(),
);

/// Provider for the current theme mode
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(),
);

/// Notifier for theme mode
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _init();
  }

  Future<void> _init() async {
    final themeModeSetting = await SettingsService.getSetting(
      'appearance.themeMode',
    );
    if (themeModeSetting != null) {
      switch (themeModeSetting) {
        case 'light':
          state = ThemeMode.light;
          break;
        case 'dark':
          state = ThemeMode.dark;
          break;
        default:
          state = ThemeMode.system;
      }
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    String modeString;
    switch (mode) {
      case ThemeMode.light:
        modeString = 'light';
        break;
      case ThemeMode.dark:
        modeString = 'dark';
        break;
      default:
        modeString = 'system';
    }
    await SettingsService.setSetting('appearance.themeMode', modeString);
  }
}

/// Notifier for accent color
class AccentColorNotifier extends StateNotifier<int> {
  AccentColorNotifier() : super(0) {
    _init();
  }

  Future<void> _init() async {
    final storedColorIndex = await SettingsService.getSetting(
      'appearance.accentColorIndex',
    );
    state = storedColorIndex ?? 0;
  }

  Future<void> setAccentColor(int index) async {
    state = index;
    await SettingsService.setSetting('appearance.accentColorIndex', index);
  }
}

/// Class to manage the app's theme and colors
class AppTheme {
  // Dark theme colors
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkSurfaceDark = Color(0xFF191919);
  static const Color darkDivider = Color(0xFF2A2A2A);
  static const Color darkOnBackground = Color(0xFFFFFFFF);
  static const Color darkOnSurface = Color(0xFFFFFFFF);
  static const Color darkDisabled = Color(0xFF636363);

  // Light theme colors
  static const Color lightBackground = Color(0xFFF7F7F7);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceDark = Color(0xFFF0F0F0);
  static const Color lightDivider = Color(0xFFE0E0E0);
  static const Color lightOnBackground = Color(0xFF121212);
  static const Color lightOnSurface = Color(0xFF121212);
  static const Color lightDisabled = Color(0xFFAAAAAA);

  // Base theme properties for current usage
  static Color get background => darkBackground;
  static Color get surface => darkSurface;
  static Color get surfaceDark => darkSurfaceDark;
  static Color get divider => darkDivider;
  static Color get onBackground => darkOnBackground;
  static Color get onSurface => darkOnSurface;
  static Color get disabled => darkDisabled;

  // Helper methods to get appropriate colors based on theme brightness
  static Color getBackgroundColor(Brightness brightness) =>
      brightness == Brightness.dark ? darkBackground : lightBackground;

  static Color getSurfaceColor(Brightness brightness) =>
      brightness == Brightness.dark ? darkSurface : lightSurface;

  static Color getSurfaceDarkColor(Brightness brightness) =>
      brightness == Brightness.dark ? darkSurfaceDark : lightSurfaceDark;

  static Color getDividerColor(Brightness brightness) =>
      brightness == Brightness.dark ? darkDivider : lightDivider;

  static Color getOnBackgroundColor(Brightness brightness) =>
      brightness == Brightness.dark ? darkOnBackground : lightOnBackground;

  static Color getOnSurfaceColor(Brightness brightness) =>
      brightness == Brightness.dark ? darkOnSurface : lightOnSurface;

  static Color getDisabledColor(Brightness brightness) =>
      brightness == Brightness.dark ? darkDisabled : lightDisabled;

  // Predefined accent colors
  static const List<Color> accentColors = [
    Color(0xFF33FFB2), // Default Nothing green
    Color(0xFF00BCD4), // Cyan
    Color(0xFFFF4081), // Pink
    Color(0xFF651FFF), // Deep Purple
    Color(0xFFFFAB00), // Amber
    Color(0xFF00E676), // Green
    Color(0xFF3D5AFE), // Indigo
    Color(0xFFFF6E40), // Deep Orange
    Color(0xFF1DE9B6), // Teal
    Color(0xFF9C27B0), // Purple
  ];

  // Color names for the accent colors
  static const List<String> accentColorNames = [
    'Nothing Green',
    'Cyan',
    'Pink',
    'Deep Purple',
    'Amber',
    'Green',
    'Indigo',
    'Deep Orange',
    'Teal',
    'Purple',
  ];

  // Get the current accent color
  static Color getAccentColor(int index) {
    if (index < 0 || index >= accentColors.length) {
      return accentColors[0];
    }
    return accentColors[index];
  }

  // Get contrasting text color (black or white) based on background color
  static Color getTextColor(Color background) {
    // Calculate luminance - if over 0.5, use black text, otherwise white
    return background.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }

  // Build dark theme
  static ThemeData buildDarkTheme(BuildContext context, int accentColorIndex) {
    final accentColor = getAccentColor(accentColorIndex);
    final textOnAccent = getTextColor(accentColor);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: accentColor,
        onPrimary: textOnAccent,
        secondary: accentColor,
        onSecondary: textOnAccent,
        background: darkBackground,
        surface: darkSurface,
        onBackground: darkOnBackground,
        onSurface: darkOnSurface,
      ),
      scaffoldBackgroundColor: darkBackground,

      // AppBar theme
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: darkBackground,
        foregroundColor: darkOnBackground,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: GoogleFonts.spaceMono(
          fontSize: 18,
          fontWeight: FontWeight.normal,
          letterSpacing: 0.5,
          color: darkOnBackground,
        ),
      ),

      // Text theme
      textTheme: GoogleFonts.spaceMonoTextTheme(
        ThemeData.dark().textTheme,
      ).apply(bodyColor: darkOnBackground, displayColor: darkOnBackground),

      // Card theme
      cardTheme: CardTheme(
        elevation: 0,
        color: darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.transparent),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      // Input decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accentColor, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),

      // Button themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: darkSurface,
          foregroundColor: darkOnSurface,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: accentColor, width: 1),
          ),
          textStyle: GoogleFonts.spaceMono(fontSize: 14, letterSpacing: 1.0),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: GoogleFonts.spaceMono(fontSize: 14, letterSpacing: 1.0),
        ),
      ),

      // FAB theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 0,
        backgroundColor: accentColor,
        foregroundColor: textOnAccent,
        shape: const CircleBorder(),
      ),

      // Switch theme
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return textOnAccent;
          }
          return Colors.white70;
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return accentColor;
          }
          return Colors.grey.shade800;
        }),
      ),

      // Other themes
      iconTheme: IconThemeData(color: accentColor, size: 24),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accentColor,
        circularTrackColor: const Color(0xFF2A2A2A),
      ),
      tabBarTheme: TabBarTheme(
        labelColor: accentColor,
        unselectedLabelColor: darkDisabled,
        indicator: BoxDecoration(
          border: Border(bottom: BorderSide(color: accentColor, width: 2)),
        ),
      ),

      // Divider theme
      dividerTheme: const DividerThemeData(
        color: darkDivider,
        thickness: 1,
        space: 1,
      ),

      // Dialog theme
      dialogTheme: DialogTheme(
        backgroundColor: darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  // Build light theme
  static ThemeData buildLightTheme(BuildContext context, int accentColorIndex) {
    final accentColor = getAccentColor(accentColorIndex);
    final textOnAccent = getTextColor(accentColor);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: accentColor,
        onPrimary: textOnAccent,
        secondary: accentColor,
        onSecondary: textOnAccent,
        background: lightBackground,
        surface: lightSurface,
        onBackground: lightOnBackground,
        onSurface: lightOnSurface,
      ),
      scaffoldBackgroundColor: lightBackground,

      // AppBar theme
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: lightBackground,
        foregroundColor: lightOnBackground,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: GoogleFonts.spaceMono(
          fontSize: 18,
          fontWeight: FontWeight.normal,
          letterSpacing: 0.5,
          color: lightOnBackground,
        ),
      ),

      // Text theme
      textTheme: GoogleFonts.spaceMonoTextTheme(
        ThemeData.light().textTheme,
      ).apply(bodyColor: lightOnBackground, displayColor: lightOnBackground),

      // Card theme
      cardTheme: CardTheme(
        elevation: 0,
        color: lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: lightDivider),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      // Input decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: lightDivider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: lightDivider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accentColor, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),

      // Button themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: lightSurface,
          foregroundColor: lightOnSurface,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: accentColor, width: 1),
          ),
          textStyle: GoogleFonts.spaceMono(fontSize: 14, letterSpacing: 1.0),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: GoogleFonts.spaceMono(fontSize: 14, letterSpacing: 1.0),
        ),
      ),

      // FAB theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 0,
        backgroundColor: accentColor,
        foregroundColor: textOnAccent,
        shape: const CircleBorder(),
      ),

      // Switch theme
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return textOnAccent;
          }
          return Colors.grey.shade400;
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return accentColor;
          }
          return Colors.grey.shade300;
        }),
      ),

      // Other themes
      iconTheme: IconThemeData(color: accentColor, size: 24),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accentColor,
        circularTrackColor: lightDivider,
      ),
      tabBarTheme: TabBarTheme(
        labelColor: accentColor,
        unselectedLabelColor: lightDisabled,
        indicator: BoxDecoration(
          border: Border(bottom: BorderSide(color: accentColor, width: 2)),
        ),
      ),

      // Divider theme
      dividerTheme: const DividerThemeData(
        color: lightDivider,
        thickness: 1,
        space: 1,
      ),

      // Dialog theme
      dialogTheme: DialogTheme(
        backgroundColor: lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  // Build theme based on current mode and accent color
  static ThemeData buildTheme(BuildContext context, int accentColorIndex) {
    // Default to dark theme for backward compatibility
    return buildDarkTheme(context, accentColorIndex);
  }

  // Button styles
  static ButtonStyle accentButtonStyle(Color accentColor, Color textColor) {
    return ElevatedButton.styleFrom(
      backgroundColor: accentColor,
      foregroundColor: textColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    );
  }

  // Decorations for settings items
  static BoxDecoration settingsItemDecoration(Brightness brightness) {
    return BoxDecoration(
      color: getSurfaceDarkColor(brightness),
      borderRadius: BorderRadius.circular(12),
    );
  }
}
