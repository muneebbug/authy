import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:authy/core/utils/secure_storage_service.dart';
import 'package:authy/core/utils/totp_service.dart';
import 'package:authy/core/utils/hive_repository.dart';
import 'package:authy/data/repositories/account_repository_impl.dart';
import 'package:authy/domain/repositories/account_repository.dart';
import 'package:authy/presentation/providers/account_provider.dart';
import 'package:authy/presentation/providers/timer_provider.dart';
import 'package:authy/presentation/screens/auth_screen.dart';
import 'package:authy/presentation/screens/home_screen.dart';
import 'package:authy/presentation/widgets/dot_pattern_background.dart';

// NothingOS theme colors
class NothingColors {
  static const Color background = Color(0xFF121212);
  static const Color surface = Color(0xFF1E1E1E);
  static const Color primary = Color(0xFF33FFB2); // Distinctive Nothing green
  static const Color onBackground = Color(0xFFFFFFFF);
  static const Color onSurface = Color(0xFFFFFFFF);
  static const Color disabled = Color(0xFF636363);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI overlay style to match NothingOS dark theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: NothingColors.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize Hive for local storage
  await Hive.initFlutter();

  // Initialize secure storage for encryption
  await SecureStorageService.init();

  // Initialize time synchronization
  await TOTPService.initTimeSync();

  // Initialize the account repository
  final accountRepository = await AccountRepositoryImpl.create();

  // Initialize Hive repository
  final hiveRepository = HiveRepository();
  await hiveRepository.init();

  // Prevent screenshots in the app for security
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    ProviderScope(
      overrides: [
        // Override the unimplemented repository with our implementation
        accountRepositoryProvider.overrideWithValue(accountRepository),
        // Override the Hive repository with our initialized instance
        hiveRepositoryProvider.overrideWithValue(hiveRepository),
      ],
      child: const AuthyApp(),
    ),
  );
}

/// Main application widget
class AuthyApp extends ConsumerWidget {
  const AuthyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Initialize the timer provider to keep timestamps updated
    // This is used for the TOTP code and remaining seconds
    ref.watch(timerProvider);

    return MaterialApp(
      title: 'Authy',
      theme: _buildNothingTheme(context),
      darkTheme: _buildNothingTheme(context),
      themeMode: ThemeMode.dark, // Always use dark theme for NothingOS look
      home: const AuthScreen(child: HomeScreen()),
      debugShowCheckedModeBanner: false,
    );
  }

  /// Build the Nothing OS inspired theme
  ThemeData _buildNothingTheme(BuildContext context) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: NothingColors.primary,
        onPrimary: Colors.black,
        background: NothingColors.background,
        surface: NothingColors.surface,
        onBackground: NothingColors.onBackground,
        onSurface: NothingColors.onSurface,
      ),
      scaffoldBackgroundColor: NothingColors.background,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: NothingColors.background,
        foregroundColor: NothingColors.onBackground,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          fontFamily: 'Nothing',
          fontSize: 18,
          fontWeight: FontWeight.normal,
          letterSpacing: 0.5,
        ),
      ),
      textTheme: GoogleFonts.spaceMonoTextTheme(
        ThemeData.dark().textTheme,
      ).apply(
        bodyColor: NothingColors.onBackground,
        displayColor: NothingColors.onBackground,
      ),
      cardTheme: CardTheme(
        elevation: 0,
        color: NothingColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.transparent),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: NothingColors.surface,
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
          borderSide: const BorderSide(color: NothingColors.primary, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: NothingColors.surface,
          foregroundColor: NothingColors.onSurface,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: NothingColors.primary, width: 1),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Nothing',
            fontSize: 14,
            letterSpacing: 1.0,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: NothingColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: const TextStyle(
            fontFamily: 'Nothing',
            fontSize: 14,
            letterSpacing: 1.0,
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        elevation: 0,
        backgroundColor: NothingColors.primary,
        foregroundColor: Colors.black,
        shape: CircleBorder(),
      ),
      iconTheme: const IconThemeData(color: NothingColors.primary, size: 24),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: NothingColors.primary,
        circularTrackColor: Color(0xFF2A2A2A),
      ),
      tabBarTheme: const TabBarTheme(
        labelColor: NothingColors.primary,
        unselectedLabelColor: NothingColors.disabled,
        indicator: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: NothingColors.primary, width: 2),
          ),
        ),
      ),
    );
  }
}
