import 'dart:convert';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service for securely storing and retrieving sensitive data
class SecureStorageService {
  static const String _encryptionKeyName = 'encryption_key';
  static final FlutterSecureStorage _secureStorage =
      const FlutterSecureStorage();
  static Key? _encryptionKey;
  static Encrypter? _encrypter;

  /// Initialize the encryption service
  static Future<void> init() async {
    try {
      print("Initializing SecureStorageService...");
      final String? storedKey = await _secureStorage.read(
        key: _encryptionKeyName,
      );

      if (storedKey == null) {
        print("No encryption key found, generating new key");
        // Generate a new encryption key if none exists
        final key = Key.fromSecureRandom(32); // AES-256 requires 32 bytes
        await _secureStorage.write(
          key: _encryptionKeyName,
          value: base64Encode(key.bytes),
        );
        _encryptionKey = key;
        print("New encryption key generated and stored");
      } else {
        print("Using existing encryption key");
        // Use the existing key
        _encryptionKey = Key(base64Decode(storedKey));
      }

      // Initialize the encrypter with the key
      _encrypter = Encrypter(AES(_encryptionKey!, mode: AESMode.cbc));
      print("Encrypter initialized successfully");
    } catch (e, stack) {
      print("Error initializing SecureStorageService: $e");
      print("Stack trace: $stack");
      rethrow;
    }
  }

  /// Encrypt a string value
  static String encrypt(String value) {
    try {
      if (_encrypter == null) {
        print("Encrypter is null, service not initialized");
        throw Exception('SecureStorageService not initialized');
      }

      final iv = IV.fromSecureRandom(16); // AES uses 16 bytes IV
      final encrypted = _encrypter!.encrypt(value, iv: iv);

      // Store the IV with the encrypted value
      final encryptedData = {
        'data': encrypted.base64,
        'iv': base64Encode(iv.bytes),
      };

      final result = jsonEncode(encryptedData);
      print("Value encrypted successfully");
      return result;
    } catch (e, stack) {
      print("Error encrypting value: $e");
      print("Stack trace: $stack");
      rethrow;
    }
  }

  /// Decrypt an encrypted string value
  static String decrypt(String encryptedValue) {
    if (_encrypter == null) {
      throw Exception('SecureStorageService not initialized');
    }

    final encryptedData = jsonDecode(encryptedValue);
    final encrypted = Encrypted.fromBase64(encryptedData['data']);
    final iv = IV(base64Decode(encryptedData['iv']));

    return _encrypter!.decrypt(encrypted, iv: iv);
  }

  /// Store a securely encrypted value in secure storage
  static Future<void> setSecureValue(String key, String value) async {
    final encryptedValue = encrypt(value);
    await _secureStorage.write(key: key, value: encryptedValue);
  }

  /// Retrieve and decrypt a value from secure storage
  static Future<String?> getSecureValue(String key) async {
    final encryptedValue = await _secureStorage.read(key: key);
    if (encryptedValue == null) {
      return null;
    }

    return decrypt(encryptedValue);
  }

  /// Remove a value from secure storage
  static Future<void> removeSecureValue(String key) async {
    await _secureStorage.delete(key: key);
  }

  /// Clear all values from secure storage
  static Future<void> clearAll() async {
    await _secureStorage.deleteAll();
  }
}
