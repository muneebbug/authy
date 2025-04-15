import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:authy/core/utils/settings_service.dart';

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
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();

      if (!canCheckBiometrics || !isDeviceSupported) {
        return false;
      }

      final availableBiometrics = await _localAuth.getAvailableBiometrics();

      return availableBiometrics.isNotEmpty;
    } on PlatformException catch (_) {
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
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Authenticate to access your accounts',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      return didAuthenticate;
    } on PlatformException catch (_) {
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
