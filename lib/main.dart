import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sentinel/core/theme/app_theme.dart';
import 'package:sentinel/core/utils/app_lifecycle_observer.dart';
import 'package:sentinel/core/utils/auth_service.dart';
import 'package:sentinel/core/utils/hive_repository.dart';
import 'package:sentinel/core/utils/secure_storage_service.dart';
import 'package:sentinel/core/utils/settings_service.dart';
import 'package:sentinel/core/utils/totp_service.dart';
import 'package:sentinel/data/repositories/account_repository_impl.dart';
import 'package:sentinel/presentation/providers/account_provider.dart';
import 'package:sentinel/presentation/providers/auth_provider.dart';
import 'package:sentinel/presentation/providers/timer_provider.dart';
import 'package:sentinel/presentation/screens/auth_screen.dart';
import 'package:sentinel/presentation/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI overlay style to match NothingOS dark theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Essential initializations before showing UI
  await Hive.initFlutter();
  await SecureStorageService.init();
  await SettingsService.init();

  // Create repositories
  final accountRepository = await AccountRepositoryImpl.create();
  final hiveRepository = HiveRepository();
  await hiveRepository.init();

  // Set portrait orientation
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    ProviderScope(
      overrides: [
        accountRepositoryProvider.overrideWithValue(accountRepository),
        hiveRepositoryProvider.overrideWithValue(hiveRepository),
      ],
      child: const SentinelApp(),
    ),
  );

  // Defer non-essential initialization for after UI is shown
  _performBackgroundInitialization();
}

/// Perform non-essential initialization tasks in the background
Future<void> _performBackgroundInitialization() async {
  // Migrate any existing settings
  await AuthService.initializeAndMigrate();

  // Pre-check biometric availability to speed up UI
  await AuthService.isBiometricAvailable();

  // Initialize time synchronization in background
  await TOTPService.initTimeSync();
}

/// Main application widget
class SentinelApp extends ConsumerStatefulWidget {
  const SentinelApp({super.key});

  @override
  ConsumerState<SentinelApp> createState() => _SentinelAppState();
}

class _SentinelAppState extends ConsumerState<SentinelApp>
    with WidgetsBindingObserver {
  late AppLifecycleObserver _lifecycleObserver;
  bool _isAppLocked = false;
  bool _isInitialized = false; // Track if initialization is complete

  @override
  void initState() {
    super.initState();
    // Register app lifecycle observer to handle app background state
    WidgetsBinding.instance.addObserver(this);
    _lifecycleObserver = AppLifecycleObserver(
      onResume: _checkAuthOnResume,
      onPause: _lockAppOnPause,
      onInactive: _lockAppOnPause, // Lock when app goes to inactive state
      onDetach: _lockAppOnPause, // Lock when app is detached
      onHidden: _lockAppOnPause, // Lock when app is hidden
    );
    _lifecycleObserver.initialize();

    // Set app to locked state on startup to force PIN entry
    // Will be handled properly in _checkInitialLockState
    _isAppLocked = true;

    // Check if we should lock on startup
    _checkInitialLockState();
  }

  Future<void> _checkInitialLockState() async {
    try {
      // First make sure SettingsService is initialized
      await SettingsService.init();

      // Preload accounts in background to avoid flash of empty content
      ref.read(accountsProvider.notifier).loadAccounts();

      // Wait for auth method provider to initialize
      while (!ref.read(authMethodProvider.notifier).isInitialized) {
        await Future.delayed(const Duration(milliseconds: 50));
      }

      // Wait for app lock provider to initialize
      while (!ref.read(appLockProvider.notifier).isInitialized) {
        await Future.delayed(const Duration(milliseconds: 50));
      }

      final authMethod = ref.read(authMethodProvider);
      final appLockEnabled = ref.read(appLockProvider);

      // Only unlock if there's no auth method or app lock is explicitly disabled
      if (mounted) {
        if (authMethod == AuthMethod.none || !appLockEnabled) {
          setState(() {
            _isAppLocked = false;
            _isInitialized = true; // Mark initialization as complete
          });
        } else {
          // Ensure app is locked if auth is required
          setState(() {
            _isAppLocked = true;
            _isInitialized = true; // Mark initialization as complete
          });
        }
      }
    } catch (e) {
      // In case of error, default to unlocked
      if (mounted) {
        setState(() {
          _isAppLocked = false;
          _isInitialized = true;
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lifecycleObserver.dispose();
    super.dispose();
  }

  // Handle app state changes
  void _lockAppOnPause() {
    // Check if app lock is enabled
    final appLockEnabled = ref.read(appLockProvider);
    final authMethod = ref.read(authMethodProvider);

    // Only lock if auth is set up and app lock is enabled
    if (appLockEnabled && authMethod != AuthMethod.none) {
      if (mounted) {
        setState(() {
          _isAppLocked = true;
        });
      }
    }
  }

  void _checkAuthOnResume() {
    // Check if we need to authenticate on resume
    final appLockEnabled = ref.read(appLockProvider);
    final authMethod = ref.read(authMethodProvider);

    // If app lock is enabled and there's an auth method set, we need to auth on resume
    if (appLockEnabled && authMethod != AuthMethod.none) {
      if (mounted) {
        setState(() {
          _isAppLocked = true;
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Also listen directly for state changes
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _lockAppOnPause();
    } else if (state == AppLifecycleState.resumed) {
      _checkAuthOnResume();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Initialize the timer provider to keep timestamps updated
    // This is used for the TOTP code and remaining seconds
    ref.watch(timerProvider);

    // Get the current accent color index
    final accentColorIndex = ref.watch(accentColorProvider);

    // Get the current theme mode
    final themeMode = ref.watch(themeModeProvider);

    // Don't show anything until initialization is complete to prevent flash
    if (!_isInitialized) {
      // Determine the background color based on theme
      final backgroundColor =
          themeMode == ThemeMode.dark
              ? AppTheme.darkBackground
              : AppTheme.lightBackground;

      return MaterialApp(
        title: 'Sentinel',
        theme: AppTheme.buildLightTheme(context, accentColorIndex),
        darkTheme: AppTheme.buildDarkTheme(context, accentColorIndex),
        themeMode: themeMode,
        home: Scaffold(
          backgroundColor: backgroundColor,
          body: Center(child: CircularProgressIndicator()),
        ),
        debugShowCheckedModeBanner: false,
      );
    }

    return MaterialApp(
      title: 'Sentinel',
      theme: AppTheme.buildLightTheme(context, accentColorIndex),
      darkTheme: AppTheme.buildDarkTheme(context, accentColorIndex),
      themeMode: themeMode,
      home:
          _isAppLocked
              ? AuthScreen(checkAppLock: true, child: HomeScreen())
              : AuthScreen(checkAppLock: false, child: HomeScreen()),
      debugShowCheckedModeBanner: false,
    );
  }
}
