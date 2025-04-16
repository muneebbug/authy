import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sentinel/core/utils/settings_service.dart';
import 'package:sentinel/core/utils/logger_util.dart';

/// Authentication methods supported by the app
enum AuthMethod {
  none, // No authentication set up
  pin, // PIN only
  biometric, // Biometric only
  both, // Both PIN and biometric are set up
}

/// Service for handling app-level authentication
class AuthService {
  static const String _pinKey = 'auth_pin';
  static const String _methodKey = 'auth_method';
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _appLockKey = 'app_lock_enabled';
  static final _secureStorage = const FlutterSecureStorage();
  static final _localAuth = LocalAuthentication();

  /// Initialize and migrate settings if needed
  static Future<void> initializeAndMigrate() async {
    // Migrate existing settings to the new settings service
    await _migrateToSettingsService();
  }

  /// Migrate existing settings to the SettingsService
  static Future<void> _migrateToSettingsService() async {
    // Migrate auth method
    final authMethod = await getAuthMethod();
    String methodString;
    switch (authMethod) {
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

    // Migrate app lock setting
    final appLockEnabled = await getSecureStorageValue(_appLockKey) == 'true';
    await SettingsService.setSetting('security.appLockEnabled', appLockEnabled);
  }

  /// Get the current authentication method
  static Future<AuthMethod> getAuthMethod() async {
    try {
      final methodString = await _secureStorage.read(key: _methodKey);
      final hasPinSet = await hasPin();
      final hasBiometricSet = await hasBiometricEnabled();

      // Handle case where both are set
      if (hasPinSet && hasBiometricSet) {
        return AuthMethod.both;
      }

      // Handle individual auth methods
      if (hasPinSet) {
        return AuthMethod.pin;
      }

      if (hasBiometricSet) {
        return AuthMethod.biometric;
      }

      // Default case - no auth method
      return AuthMethod.none;
    } catch (e, stack) {
      LoggerUtil.error(
        'Error reading auth method from secure storage',
        e,
        stack,
      );
      // Return none on any storage read errors
      return AuthMethod.none;
    }
  }

  /// Set the authentication method
  static Future<void> setAuthMethod(AuthMethod method) async {
    String methodString;

    switch (method) {
      case AuthMethod.pin:
        methodString = 'pin';
        // If setting PIN only, disable biometric
        await _secureStorage.write(key: _biometricEnabledKey, value: 'false');
        break;
      case AuthMethod.biometric:
        methodString = 'biometric';
        break;
      case AuthMethod.both:
        methodString = 'both';
        // Ensure both are enabled
        await _secureStorage.write(key: _biometricEnabledKey, value: 'true');
        break;
      default:
        methodString = 'none';
        // Clear both PIN and biometric
        await _secureStorage.write(key: _biometricEnabledKey, value: 'false');
        await _secureStorage.delete(key: _pinKey);
    }

    await _secureStorage.write(key: _methodKey, value: methodString);
  }

  /// Check if biometric authentication is available
  static Future<bool> isBiometricAvailable() async {
    try {
      LoggerUtil.section('BIOMETRIC AVAILABILITY CHECK');

      // First check if device supports biometrics
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      LoggerUtil.debug('Device supports biometrics: $isDeviceSupported');

      if (!isDeviceSupported) {
        LoggerUtil.warning('Device does not support biometric authentication');
        return false;
      }

      // Then check if biometrics are available on this device
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      LoggerUtil.debug('Can check biometrics: $canCheckBiometrics');

      if (!canCheckBiometrics) {
        LoggerUtil.warning(
          'Biometric authentication not available on this device',
        );
        return false;
      }

      // Check which biometrics are available
      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      LoggerUtil.debug('Available biometrics: $availableBiometrics');

      if (availableBiometrics.isEmpty) {
        LoggerUtil.warning('No biometrics have been enrolled on this device');
        return false;
      }

      // Check if device has fingerprint
      final hasFingerprint = availableBiometrics.contains(
        BiometricType.fingerprint,
      );
      // Check if device has face ID
      final hasFaceId = availableBiometrics.contains(BiometricType.face);
      // Check if device has iris scanning
      final hasIris = availableBiometrics.contains(BiometricType.iris);
      // Check if device has strong biometrics
      final hasStrongBiometrics = availableBiometrics.contains(
        BiometricType.strong,
      );

      LoggerUtil.debug('Has fingerprint: $hasFingerprint');
      LoggerUtil.debug('Has face ID: $hasFaceId');
      LoggerUtil.debug('Has iris scanning: $hasIris');
      LoggerUtil.debug('Has strong biometrics: $hasStrongBiometrics');

      // Try a test authentication to see if we have permission
      try {
        // This method doesn't exist, removing it
        // final bool canAuthenticate = await _localAuth.canCheck();
      } catch (e) {
        LoggerUtil.error('Error checking if can authenticate', e);
      }

      LoggerUtil.info('Biometric authentication is available');
      return true;
    } on PlatformException catch (e) {
      LoggerUtil.error('Error checking biometric availability', e);
      LoggerUtil.debug('Error details: ${e.details}');
      LoggerUtil.debug('Error code: ${e.code}');
      return false;
    } catch (e) {
      LoggerUtil.error('Unexpected error checking biometric availability', e);
      return false;
    }
  }

  /// Set a PIN code
  static Future<void> setPin(String pin) async {
    await _secureStorage.write(key: _pinKey, value: pin);

    // Check if biometric is also enabled
    final hasBiometric = await hasBiometricEnabled();
    if (hasBiometric) {
      await setAuthMethod(AuthMethod.both);
    } else {
      await setAuthMethod(AuthMethod.pin);
    }
  }

  /// Validate a PIN code
  static Future<bool> validatePin(String pin) async {
    try {
      final storedPin = await _secureStorage.read(key: _pinKey);
      return storedPin == pin;
    } catch (e, stack) {
      LoggerUtil.error('Error validating PIN', e, stack);
      // Return false on any storage read errors
      return false;
    }
  }

  /// Authenticate with biometrics
  static Future<bool> authenticateWithBiometrics() async {
    try {
      LoggerUtil.section('BIOMETRIC AUTHENTICATION');

      // First check basic device support (without getting into detailed checks)
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      if (!isDeviceSupported) {
        LoggerUtil.warning('Device does not support biometric authentication');
        return false;
      }

      // Directly try to authenticate rather than doing extensive availability checks
      // This approach is more reliable as the local_auth plugin will handle the appropriate fallbacks
      LoggerUtil.debug('Attempting biometric authentication...');
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Authenticate to access your accounts',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (didAuthenticate) {
        LoggerUtil.info('Biometric authentication successful');
      } else {
        LoggerUtil.warning(
          'Biometric authentication failed or canceled by user',
        );
      }

      return didAuthenticate;
    } on PlatformException catch (e) {
      LoggerUtil.error('Biometric authentication error', e);
      LoggerUtil.debug('Error details: ${e.details}');
      LoggerUtil.debug('Error code: ${e.code}');
      return false;
    } catch (e) {
      LoggerUtil.error('Unexpected error during biometric authentication', e);
      return false;
    }
  }

  /// Authenticate with PIN
  static Future<bool> authenticateWithPin(String pin) async {
    return validatePin(pin);
  }

  /// Remove authentication
  static Future<void> removeAuthentication() async {
    await _secureStorage.delete(key: _pinKey);
    await _secureStorage.write(key: _biometricEnabledKey, value: 'false');
    await setAuthMethod(AuthMethod.none);
  }

  /// Check if a PIN is set
  static Future<bool> hasPin() async {
    try {
      final pin = await _secureStorage.read(key: _pinKey);
      return pin != null && pin.isNotEmpty;
    } catch (e, stack) {
      LoggerUtil.error('Error checking if PIN is set', e, stack);
      // If we can't read the PIN, assume it's not set to avoid blocking the user
      return false;
    }
  }

  /// Get a value from secure storage
  static Future<String?> getSecureStorageValue(String key) async {
    try {
      return await _secureStorage.read(key: key);
    } catch (e, stack) {
      LoggerUtil.error('Error reading from secure storage: $key', e, stack);
      // Return null on any storage read errors
      return null;
    }
  }

  /// Set a value in secure storage
  static Future<void> setSecureStorageValue(String key, String value) async {
    await _secureStorage.write(key: key, value: value);
  }

  /// Reset secure storage in case of corruption
  static Future<void> resetSecureStorage() async {
    try {
      LoggerUtil.warning('Resetting secure storage due to corruption or error');
      // Delete all secure storage keys
      await _secureStorage.deleteAll();

      // Reset settings to default
      await SettingsService.setSetting('security.authMethod', 'none');
      await SettingsService.setSetting('security.appLockEnabled', false);

      LoggerUtil.info('Secure storage has been reset');
    } catch (e, stack) {
      LoggerUtil.error('Error resetting secure storage', e, stack);
      rethrow;
    }
  }

  /// Attempt to recover from secure storage errors
  static Future<bool> attemptStorageRecovery() async {
    try {
      LoggerUtil.warning('Attempting to recover from secure storage errors');

      // Try to read a key to verify if storage is working
      final testResult = await getSecureStorageValue('test_recovery');

      // If we can read without errors, assume we're good
      LoggerUtil.info('Storage recovery test passed');
      return true;
    } catch (e, stack) {
      LoggerUtil.error('Storage recovery test failed', e, stack);

      // If test fails, reset the storage
      await resetSecureStorage();
      return false;
    }
  }

  /// Enable biometric authentication
  static Future<bool> enableBiometric() async {
    final biometricAvailable = await isBiometricAvailable();
    if (!biometricAvailable) {
      LoggerUtil.warning('Biometrics not available, cannot enable');
      return false;
    }

    try {
      await _secureStorage.write(key: _biometricEnabledKey, value: 'true');

      // Check if PIN is also set
      final isPinSet = await hasPin();
      if (isPinSet) {
        await setAuthMethod(AuthMethod.both);
      } else {
        await setAuthMethod(AuthMethod.biometric);
      }

      LoggerUtil.info('Biometric authentication enabled successfully');
      return true;
    } catch (e, stack) {
      LoggerUtil.error('Error enabling biometric authentication', e, stack);
      return false;
    }
  }

  /// Disable biometric authentication
  static Future<void> disableBiometric() async {
    await _secureStorage.write(key: _biometricEnabledKey, value: 'false');

    // Check if PIN is still set
    final hasPinSet = await hasPin();
    if (hasPinSet) {
      await setAuthMethod(AuthMethod.pin);
    } else {
      await setAuthMethod(AuthMethod.none);
    }
  }

  /// Check if biometric authentication is enabled
  static Future<bool> hasBiometricEnabled() async {
    try {
      final value = await _secureStorage.read(key: _biometricEnabledKey);
      return value == 'true';
    } catch (e, stack) {
      LoggerUtil.error('Error checking if biometric is enabled', e, stack);
      return false;
    }
  }

  /// Remove PIN but keep biometric if enabled
  static Future<void> removePin() async {
    await _secureStorage.delete(key: _pinKey);

    // Check if biometric is still enabled
    final isBiometricEnabled = await hasBiometricEnabled();
    if (isBiometricEnabled) {
      await setAuthMethod(AuthMethod.biometric);
    } else {
      await setAuthMethod(AuthMethod.none);
    }
  }
}
