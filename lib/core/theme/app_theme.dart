import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:authy/core/utils/settings_service.dart';

/// Provider for the current accent color index
final accentColorProvider = StateNotifierProvider<AccentColorNotifier, int>(
  (ref) => AccentColorNotifier(),
);

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
  // Base colors
  static const Color background = Color(0xFF121212);
  static const Color surface = Color(0xFF1E1E1E);
  static const Color surfaceDark = Color(0xFF191919);
  static const Color divider = Color(0xFF2A2A2A);
  static const Color onBackground = Color(0xFFFFFFFF);
  static const Color onSurface = Color(0xFFFFFFFF);
  static const Color disabled = Color(0xFF636363);

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

  // Build app theme based on accent color
  static ThemeData buildTheme(BuildContext context, int accentColorIndex) {
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
        background: background,
        surface: surface,
        onBackground: onBackground,
        onSurface: onSurface,
      ),
      scaffoldBackgroundColor: background,

      // AppBar theme
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: background,
        foregroundColor: onBackground,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: GoogleFonts.spaceMono(
          fontSize: 18,
          fontWeight: FontWeight.normal,
          letterSpacing: 0.5,
          color: onBackground,
        ),
      ),

      // Text theme
      textTheme: GoogleFonts.spaceMonoTextTheme(
        ThemeData.dark().textTheme,
      ).apply(bodyColor: onBackground, displayColor: onBackground),

      // Card theme
      cardTheme: CardTheme(
        elevation: 0,
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.transparent),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      // Input decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
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
          backgroundColor: surface,
          foregroundColor: onSurface,
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
        unselectedLabelColor: disabled,
        indicator: BoxDecoration(
          border: Border(bottom: BorderSide(color: accentColor, width: 2)),
        ),
      ),

      // Divider theme
      dividerTheme: const DividerThemeData(
        color: divider,
        thickness: 1,
        space: 1,
      ),

      // Dialog theme
      dialogTheme: DialogTheme(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
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

  static ButtonStyle surfaceButtonStyle(Color accentColor) {
    return ElevatedButton.styleFrom(
      backgroundColor: surface,
      foregroundColor: onSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: accentColor, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    );
  }

  // Settings item style
  static BoxDecoration settingsItemDecoration() {
    return BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(12),
    );
  }
}
