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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
      theme: _buildTheme(context),
      home: const AuthScreen(child: HomeScreen()),
      debugShowCheckedModeBanner: false,
    );
  }

  /// Build the app theme
  ThemeData _buildTheme(BuildContext context) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2196F3),
        brightness: Brightness.light,
      ),
      textTheme: GoogleFonts.nunitoSansTextTheme(Theme.of(context).textTheme),
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        centerTitle: true,
        titleTextStyle: GoogleFonts.nunitoSans(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        elevation: 4,
        foregroundColor: Colors.white,
      ),
    );
  }
}
