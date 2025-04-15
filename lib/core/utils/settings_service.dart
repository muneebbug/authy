import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service for managing app settings in a centralized way
/// All settings are stored in a structured format that can be easily synced
class SettingsService {
  static const String _settingsKey = 'app_settings';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  /// Default settings
  static const Map<String, dynamic> _defaultSettings = {
    'appearance': {'accentColorIndex': 0, 'darkMode': true},
    'security': {
      'authMethod': 'none', // 'none', 'pin', 'biometric'
      'appLockEnabled': false,
    },
    'sync': {'enabled': false, 'lastSyncTimestamp': null},
    'notifications': {'enabled': true},
  };

  /// Current settings cache
  static Map<String, dynamic>? _cachedSettings;

  /// Track if initialization has completed
  static bool _isInitialized = false;

  /// Initialize the settings service
  static Future<void> init() async {
    // Skip if already initialized to avoid duplicate work
    if (_isInitialized) return;

    await loadSettings();
    _isInitialized = true;
  }

  /// Check if the service is initialized
  static bool isInitialized() {
    return _isInitialized;
  }

  /// Load settings from storage
  static Future<Map<String, dynamic>> loadSettings() async {
    try {
      final settingsJson = await _secureStorage.read(key: _settingsKey);

      if (settingsJson == null) {
        _cachedSettings = Map<String, dynamic>.from(_defaultSettings);
        await saveSettings(_cachedSettings!);
        return _cachedSettings!;
      }

      _cachedSettings = Map<String, dynamic>.from(jsonDecode(settingsJson));
      return _cachedSettings!;
    } catch (e) {
      // If there's an error reading settings, use defaults
      _cachedSettings = Map<String, dynamic>.from(_defaultSettings);
      await saveSettings(_cachedSettings!);
      return _cachedSettings!;
    }
  }

  /// Save settings to storage
  static Future<void> saveSettings(Map<String, dynamic> settings) async {
    _cachedSettings = settings;
    final settingsJson = jsonEncode(settings);
    await _secureStorage.write(key: _settingsKey, value: settingsJson);
  }

  /// Get a specific setting by path (e.g., 'appearance.accentColorIndex')
  static Future<dynamic> getSetting(String path) async {
    final pathParts = path.split('.');

    if (_cachedSettings == null) {
      await loadSettings();
    }

    Map<String, dynamic> current = _cachedSettings!;

    for (int i = 0; i < pathParts.length - 1; i++) {
      if (!current.containsKey(pathParts[i])) {
        return _getDefaultSettingByPath(path);
      }
      current = current[pathParts[i]];
    }

    final lastKey = pathParts.last;
    if (!current.containsKey(lastKey)) {
      return _getDefaultSettingByPath(path);
    }

    return current[lastKey];
  }

  /// Set a specific setting by path (e.g., 'appearance.accentColorIndex')
  static Future<void> setSetting(String path, dynamic value) async {
    final pathParts = path.split('.');

    if (_cachedSettings == null) {
      await loadSettings();
    }

    Map<String, dynamic> current = _cachedSettings!;

    for (int i = 0; i < pathParts.length - 1; i++) {
      if (!current.containsKey(pathParts[i])) {
        current[pathParts[i]] = {};
      }
      current = current[pathParts[i]];
    }

    current[pathParts.last] = value;
    await saveSettings(_cachedSettings!);
  }

  /// Reset settings to default
  static Future<void> resetSettings() async {
    _cachedSettings = Map<String, dynamic>.from(_defaultSettings);
    await saveSettings(_cachedSettings!);
  }

  /// Get full settings object for sync
  static Future<Map<String, dynamic>> getFullSettings() async {
    if (_cachedSettings == null) {
      await loadSettings();
    }
    return Map<String, dynamic>.from(_cachedSettings!);
  }

  /// Import settings (for sync)
  static Future<void> importSettings(Map<String, dynamic> settings) async {
    _cachedSettings = settings;
    await saveSettings(_cachedSettings!);
  }

  /// Get default setting by path
  static dynamic _getDefaultSettingByPath(String path) {
    final pathParts = path.split('.');
    Map<String, dynamic> current = _defaultSettings;

    for (int i = 0; i < pathParts.length - 1; i++) {
      if (!current.containsKey(pathParts[i])) {
        return null;
      }
      current = current[pathParts[i]];
    }

    final lastKey = pathParts.last;
    if (!current.containsKey(lastKey)) {
      return null;
    }

    return current[lastKey];
  }
}
