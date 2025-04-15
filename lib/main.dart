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
import 'package:authy/core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI overlay style to match NothingOS dark theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.background,
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

    // Get the current accent color index
    final accentColorIndex = ref.watch(accentColorProvider);

    return MaterialApp(
      title: 'Authy',
      theme: AppTheme.buildTheme(context, accentColorIndex),
      darkTheme: AppTheme.buildTheme(context, accentColorIndex),
      themeMode: ThemeMode.dark, // Always use dark theme for NothingOS look
      home: const AuthScreen(child: HomeScreen()),
      debugShowCheckedModeBanner: false,
    );
  }
}
