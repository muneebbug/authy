import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:cryptography/cryptography.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sentinel/domain/entities/account.dart';
import 'package:sentinel/core/utils/secure_storage_service.dart';

/// Service for handling secure export and import of accounts
class SecureExportService {
  // Words for generating passphrases - similar to Signal/Session
  static const List<String> _passphraseWords = [
    'apple',
    'banana',
    'orange',
    'grape',
    'kiwi',
    'mango',
    'pear',
    'peach',
    'plum',
    'cherry',
    'lemon',
    'lime',
    'melon',
    'berry',
    'coconut',
    'pineapple',
    'river',
    'ocean',
    'lake',
    'mountain',
    'valley',
    'forest',
    'desert',
    'island',
    'cloud',
    'rain',
    'snow',
    'wind',
    'storm',
    'thunder',
    'sunset',
    'sunrise',
    'star',
    'moon',
    'planet',
    'galaxy',
    'universe',
    'rocket',
    'satellite',
    'comet',
    'tiger',
    'lion',
    'bear',
    'wolf',
    'fox',
    'deer',
    'rabbit',
    'squirrel',
    'eagle',
    'hawk',
    'owl',
    'falcon',
    'sparrow',
    'robin',
    'parrot',
    'peacock',
    'blue',
    'red',
    'green',
    'yellow',
    'purple',
    'orange',
    'pink',
    'brown',
    'black',
    'white',
    'gray',
    'silver',
    'gold',
    'bronze',
    'copper',
    'platinum',
  ];

  /// Generate a secure random passphrase with 6 words
  static String generatePassphrase() {
    final random = Random.secure();
    final words = <String>[];

    for (int i = 0; i < 16; i++) {
      final index = random.nextInt(_passphraseWords.length);
      words.add(_passphraseWords[index]);
    }

    return words.join(' ');
  }

  /// Export accounts to an encrypted file
  /// Returns the passphrase and the file path
  static Future<Map<String, String>> exportAccounts(
    List<Account> accounts,
  ) async {
    try {
      // Generate secure passphrase
      final passphrase = generatePassphrase();

      // Prepare data for export
      final jsonData = jsonEncode({
        'accounts': accounts.map((a) => _accountToJson(a)).toList(),
        'exportDate': DateTime.now().toIso8601String(),
        'appVersion': '1.0.0',
      });

      // Encrypt the data
      final encryptedData = await _encryptData(jsonData, passphrase);

      // Save to file
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'sentinel_export_${DateTime.now().millisecondsSinceEpoch}.sav';
      final file = File('${directory.path}/$fileName');

      // Create file format with header to identify our app
      final header = Uint8List.fromList(
        utf8.encode('SENTINEL_SECURE_EXPORT_1.0'),
      );
      final fileData = Uint8List.fromList([...header, ...encryptedData]);

      await file.writeAsBytes(fileData);

      return {'passphrase': passphrase, 'filePath': file.path};
    } catch (e) {
      throw Exception('Failed to export accounts: $e');
    }
  }

  /// Import accounts from an encrypted file
  /// Returns the list of imported accounts
  static Future<List<Account>> importAccounts(
    String filePath,
    String passphrase,
  ) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File does not exist');
      }

      final fileData = await file.readAsBytes();

      // Verify header
      final headerLength = 'SENTINEL_SECURE_EXPORT_1.0'.length;
      if (fileData.length <= headerLength) {
        throw Exception('Invalid file format');
      }

      final header = utf8.decode(fileData.sublist(0, headerLength));
      if (header != 'SENTINEL_SECURE_EXPORT_1.0') {
        throw Exception('Not a Sentinel export file');
      }

      // Extract encrypted data
      final encryptedData = fileData.sublist(headerLength);

      // Decrypt the data
      final jsonData = await _decryptData(encryptedData, passphrase);

      // Parse the data
      final Map<String, dynamic> data = jsonDecode(jsonData);
      if (!data.containsKey('accounts')) {
        throw Exception('Invalid export file format');
      }

      final List<dynamic> accountsJson = data['accounts'];
      return accountsJson.map((json) => _jsonToAccount(json)).toList();
    } catch (e) {
      throw Exception('Failed to import accounts: $e');
    }
  }

  /// Convert Account to JSON
  static Map<String, dynamic> _accountToJson(Account account) {
    return {
      'id': account.id,
      'issuer': account.issuer,
      'accountName': account.accountName,
      'secretKey': account.secretKey,
      'algorithm': account.algorithm.index,
      'digits': account.digits,
      'period': account.period,
      'colorCode': account.colorCode,
      'lastUsedAt': account.lastUsedAt.toIso8601String(),
      'createdAt': account.createdAt.toIso8601String(),
    };
  }

  /// Convert JSON to Account
  static Account _jsonToAccount(Map<String, dynamic> json) {
    return Account(
      id: json['id'],
      issuer: json['issuer'],
      accountName: json['accountName'],
      secretKey: json['secretKey'],
      algorithm: Algorithm.values[json['algorithm']],
      digits: json['digits'],
      period: json['period'],
      colorCode: json['colorCode'],
      lastUsedAt: DateTime.parse(json['lastUsedAt']),
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  /// Encrypt data using the passphrase
  static Future<Uint8List> _encryptData(String data, String passphrase) async {
    // Generate a secure key from the passphrase
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 10000,
      bits: 256,
    );

    // Use a fixed salt for simplicity (could be enhanced with random salt)
    final salt = Uint8List.fromList(utf8.encode('SentinelAppSecureExport'));

    // Derive key from passphrase
    final secretKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: salt,
    );
    final keyBytes = await secretKey.extractBytes();

    // Create AES key and IV
    final key = encrypt.Key(Uint8List.fromList(keyBytes));
    final iv = encrypt.IV.fromSecureRandom(16);

    // Encrypt the data
    final encrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.cbc),
    );
    final encrypted = encrypter.encrypt(data, iv: iv);

    // Combine IV and encrypted data
    final result = List<int>.from([...iv.bytes, ...encrypted.bytes]);
    return Uint8List.fromList(result);
  }

  /// Decrypt data using the passphrase
  static Future<String> _decryptData(
    Uint8List encryptedData,
    String passphrase,
  ) async {
    // Generate the key from the passphrase
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 10000,
      bits: 256,
    );

    // Use the same salt as encryption
    final salt = Uint8List.fromList(utf8.encode('SentinelAppSecureExport'));

    // Derive key from passphrase
    final secretKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: salt,
    );
    final keyBytes = await secretKey.extractBytes();

    // Extract IV and encrypted data
    final iv = encrypt.IV(encryptedData.sublist(0, 16));
    final encryptedBytes = encryptedData.sublist(16);

    // Create AES key
    final key = encrypt.Key(Uint8List.fromList(keyBytes));

    // Decrypt the data
    final encrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.cbc),
    );
    final decrypted = encrypter.decrypt(
      encrypt.Encrypted(encryptedBytes),
      iv: iv,
    );

    return decrypted;
  }
}
