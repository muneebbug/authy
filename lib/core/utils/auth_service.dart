import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sentinel/core/utils/settings_service.dart';
import 'package:sentinel/core/utils/logger_util.dart';

/// Authentication methods supported by the app
enum AuthMethod { none, pin, biometric }

/// Service for handling app-level authentication
class AuthService {
  static const String _pinKey = 'auth_pin';
  static const String _methodKey = 'auth_method';
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
    final methodString = await _secureStorage.read(key: _methodKey);

    if (methodString == null) {
      return AuthMethod.none;
    }

    switch (methodString) {
      case 'pin':
        return AuthMethod.pin;
      case 'biometric':
        return AuthMethod.biometric;
      default:
        return AuthMethod.none;
    }
  }

  /// Set the authentication method
  static Future<void> setAuthMethod(AuthMethod method) async {
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
    await setAuthMethod(AuthMethod.pin);
  }

  /// Validate a PIN code
  static Future<bool> validatePin(String pin) async {
    final storedPin = await _secureStorage.read(key: _pinKey);
    return storedPin == pin;
  }

  /// Authenticate with biometrics
  static Future<bool> authenticateWithBiometrics() async {
    try {
      LoggerUtil.section('BIOMETRIC AUTHENTICATION');

      // First check if biometrics are available
      final biometricsAvailable = await isBiometricAvailable();
      if (!biometricsAvailable) {
        LoggerUtil.warning('Biometrics not available, authentication failed');
        return false;
      }

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
        LoggerUtil.warning('Biometric authentication failed');
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
    await setAuthMethod(AuthMethod.none);
  }

  /// Check if a PIN is set
  static Future<bool> hasPin() async {
    final pin = await _secureStorage.read(key: _pinKey);
    return pin != null && pin.isNotEmpty;
  }

  /// Get a value from secure storage
  static Future<String?> getSecureStorageValue(String key) async {
    return await _secureStorage.read(key: key);
  }

  /// Set a value in secure storage
  static Future<void> setSecureStorageValue(String key, String value) async {
    await _secureStorage.write(key: key, value: value);
  }
}
