import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:authy/core/utils/auth_service.dart';
import 'package:authy/core/utils/settings_service.dart';

/// Provider for the current authentication method
final authMethodProvider =
    StateNotifierProvider<AuthMethodNotifier, AuthMethod>(
      (ref) => AuthMethodNotifier(),
    );

/// Provider for app lock setting
final appLockProvider = StateNotifierProvider<AppLockNotifier, bool>(
  (ref) => AppLockNotifier(),
);

/// Provider for biometric authentication availability
final biometricAvailableProvider = FutureProvider<bool>((ref) async {
  try {
    print('Checking biometric availability in provider...');
    final isAvailable = await AuthService.isBiometricAvailable();
    print('Biometric availability result: $isAvailable');
    return isAvailable;
  } catch (e) {
    print('Error checking biometric availability: $e');
    return false;
  }
});

/// Provider to force refresh biometric status
final biometricRefreshProvider = StateProvider<int>((ref) => 0);

/// Provider for biometric authentication availability with refresh capability
final refreshableBiometricProvider = FutureProvider<bool>((ref) async {
  // Watch the refresh counter to rebuild when needed
  ref.watch(biometricRefreshProvider);
  return await AuthService.isBiometricAvailable();
});

/// Notifier for authentication method
class AuthMethodNotifier extends StateNotifier<AuthMethod> {
  bool _isInitialized = false;

  AuthMethodNotifier() : super(AuthMethod.none) {
    _init();
  }

  bool get isInitialized => _isInitialized;

  Future<void> _init() async {
    try {
      // First check the settings service for the auth method (more reliable)
      final methodString = await SettingsService.getSetting(
        'security.authMethod',
      );
      AuthMethod method;

      switch (methodString) {
        case 'pin':
          method = AuthMethod.pin;
          break;
        case 'biometric':
          method = AuthMethod.biometric;
          break;
        default:
          // If not found in settings service, try the older storage
          method = await AuthService.getAuthMethod();
      }

      // Update settings service with the current method
      await _updateSettingsServiceAuthMethod(method);

      state = method;
    } catch (e) {
      // In case of error, fall back to no auth
      state = AuthMethod.none;
    } finally {
      _isInitialized = true;
    }
  }

  Future<void> setAuthMethod(AuthMethod method) async {
    await AuthService.setAuthMethod(method);
    await _updateSettingsServiceAuthMethod(method);
    state = method;
  }

  Future<void> setPin(String pin) async {
    await AuthService.setPin(pin);
    await _updateSettingsServiceAuthMethod(AuthMethod.pin);
    state = AuthMethod.pin;
  }

  Future<bool> setBiometric() async {
    final biometricAvailable = await AuthService.isBiometricAvailable();
    if (biometricAvailable) {
      try {
        await AuthService.setAuthMethod(AuthMethod.biometric);
        await _updateSettingsServiceAuthMethod(AuthMethod.biometric);
        state = AuthMethod.biometric;
        print('Biometric authentication enabled successfully');
        return true;
      } catch (e) {
        print('Error enabling biometric authentication: $e');
        return false;
      }
    } else {
      print('Biometrics not available, cannot enable');
      return false;
    }
  }

  Future<void> removeAuthentication() async {
    await AuthService.removeAuthentication();
    await _updateSettingsServiceAuthMethod(AuthMethod.none);
    state = AuthMethod.none;
  }

  // Update settings service with auth method
  Future<void> _updateSettingsServiceAuthMethod(AuthMethod method) async {
    String methodString;
    switch (method) {
      case AuthMethod.pin:
        methodString = 'pin';
        break;
      case AuthMethod.biometric:
        methodString = 'biometric';
        break;
      default:
        methodString = 'none';
    }

    await SettingsService.setSetting('security.authMethod', methodString);
  }
}

/// Notifier for app lock setting
class AppLockNotifier extends StateNotifier<bool> {
  static const String _appLockKey = 'app_lock_enabled';
  bool _isInitialized = false;

  AppLockNotifier() : super(false) {
    _init();
  }

  bool get isInitialized => _isInitialized;

  Future<void> _init() async {
    try {
      // First check the settings service (more reliable)
      final settingsValue = await SettingsService.getSetting(
        'security.appLockEnabled',
      );

      // If we have a value from settings service, use it
      if (settingsValue != null) {
        state = settingsValue;
      } else {
        // Otherwise fall back to old storage
        final appLockEnabled = await _getAppLockSetting();
        state = appLockEnabled;
      }

      // Update settings service
      await SettingsService.setSetting('security.appLockEnabled', state);
    } catch (e) {
      // In case of error, default to false
      state = false;
    } finally {
      _isInitialized = true;
    }
  }

  Future<bool> _getAppLockSetting() async {
    final authMethod = await AuthService.getAuthMethod();
    if (authMethod == AuthMethod.none) {
      return false;
    }

    final result = await AuthService.getSecureStorageValue(_appLockKey);
    return result == 'true';
  }

  Future<void> setAppLock(bool enabled) async {
    // If we're enabling app lock, make sure we have authentication set up
    if (enabled) {
      final authMethod = await AuthService.getAuthMethod();
      if (authMethod == AuthMethod.none) {
        // Cannot enable app lock without an authentication method
        return;
      }
    }

    await AuthService.setSecureStorageValue(_appLockKey, enabled.toString());
    await SettingsService.setSetting('security.appLockEnabled', enabled);
    state = enabled;
  }
}
