import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentinel/core/utils/auth_service.dart';
import 'package:sentinel/core/utils/settings_service.dart';
import 'package:sentinel/core/utils/logger_util.dart';

/// Provider for the current authentication method
final authMethodProvider =
    StateNotifierProvider<AuthMethodNotifier, AuthMethod>(
      (ref) => AuthMethodNotifier(),
    );

/// Provider for app lock setting
final appLockProvider = StateNotifierProvider<AppLockNotifier, bool>(
  (ref) => AppLockNotifier(),
);

/// Provider that indicates whether authentication is actually required
/// This combines the app lock setting and auth method
final authRequiredProvider = Provider<bool>((ref) {
  final appLockEnabled = ref.watch(appLockProvider);
  final authMethod = ref.watch(authMethodProvider);

  // Authentication is required only if:
  // 1. App lock is enabled AND
  // 2. An auth method is set (either PIN, biometric, or both)
  return appLockEnabled && authMethod != AuthMethod.none;
});

/// Provider for biometric authentication availability
final biometricAvailableProvider = FutureProvider<bool>((ref) async {
  try {
    LoggerUtil.debug('Checking biometric availability in provider...');
    final isAvailable = await AuthService.isBiometricAvailable();
    LoggerUtil.debug('Biometric availability result: $isAvailable');
    return isAvailable;
  } catch (e) {
    LoggerUtil.error('Error checking biometric availability', e);
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
        case 'both':
          method = AuthMethod.both;
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
    // The updated method will handle proper state based on whether biometric is also enabled
    final newAuthMethod = await AuthService.getAuthMethod();
    await _updateSettingsServiceAuthMethod(newAuthMethod);
    state = newAuthMethod;
  }

  Future<bool> setBiometric() async {
    try {
      final success = await AuthService.enableBiometric();
      if (success) {
        // Get the updated auth method which might be 'both' if PIN is also set
        final newAuthMethod = await AuthService.getAuthMethod();
        await _updateSettingsServiceAuthMethod(newAuthMethod);
        state = newAuthMethod;
      }
      return success;
    } catch (e) {
      LoggerUtil.error('Error enabling biometric authentication', e);
      return false;
    }
  }

  Future<void> disableBiometric() async {
    await AuthService.disableBiometric();
    final newAuthMethod = await AuthService.getAuthMethod();
    await _updateSettingsServiceAuthMethod(newAuthMethod);
    state = newAuthMethod;
  }

  Future<void> removeAuthentication() async {
    await AuthService.removeAuthentication();
    await _updateSettingsServiceAuthMethod(AuthMethod.none);
    state = AuthMethod.none;
  }

  Future<void> removePin() async {
    await AuthService.removePin();
    final newAuthMethod = await AuthService.getAuthMethod();
    await _updateSettingsServiceAuthMethod(newAuthMethod);
    state = newAuthMethod;
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
      case AuthMethod.both:
        methodString = 'both';
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
    // For safety, if no auth method is set, don't enable app lock
    if (authMethod == AuthMethod.none) {
      return false;
    }

    final result = await AuthService.getSecureStorageValue(_appLockKey);
    return result == 'true';
  }

  Future<void> setAppLock(bool enabled) async {
    // Safety check - don't allow app lock if no auth method
    final authMethod = await AuthService.getAuthMethod();
    if (enabled && authMethod == AuthMethod.none) {
      LoggerUtil.warning('Cannot enable app lock without auth method');
      return;
    }

    // Update storage
    await AuthService.setSecureStorageValue(_appLockKey, enabled.toString());

    // Update settings service
    await SettingsService.setSetting('security.appLockEnabled', enabled);

    // Update state
    state = enabled;
  }
}
