import 'package:hive_flutter/hive_flutter.dart';
import 'package:authy/domain/entities/account.dart';
import 'package:authy/data/models/account_model.dart';
import 'package:authy/core/utils/secure_storage_service.dart';

/// Repository for interacting with Hive storage
class HiveRepository {
  static const String _boxName = 'accounts';
  late Box<AccountModel> _accountBox;

  /// Initialize the repository
  Future<void> init() async {
    try {
      print("Initializing HiveRepository...");

      // Register adapter for AccountModel if not already registered
      if (!Hive.isAdapterRegistered(0)) {
        print("Registering AccountModelAdapter");
        Hive.registerAdapter(AccountModelAdapter());
      }

      // Register adapter for Algorithm enum if not already registered
      if (!Hive.isAdapterRegistered(2)) {
        print("Registering Algorithm enum adapter");
        Hive.registerAdapter(AlgorithmAdapter());
      }

      print("Opening Hive box: $_boxName");
      _accountBox = await Hive.openBox<AccountModel>(_boxName);
      print("Hive box opened successfully, count: ${_accountBox.length}");
    } catch (e, stack) {
      print("Error initializing HiveRepository: $e");
      print("Stack trace: $stack");
      rethrow;
    }
  }

  /// Get all accounts from storage
  Future<List<Account>> getAccounts() async {
    try {
      print("Getting all accounts, count: ${_accountBox.length}");
      final accounts = _accountBox.values.toList();
      final List<Account> decryptedAccounts = [];

      for (final account in accounts) {
        try {
          final decryptedSecretKey = SecureStorageService.decrypt(
            account.secretKey,
          );
          final decryptedAccount = account.copyWith(
            secretKey: decryptedSecretKey,
          );
          decryptedAccounts.add(decryptedAccount);
        } catch (e) {
          print("Error decrypting account: $e");
          // Skip accounts with invalid encryption
          continue;
        }
      }

      print("Returned ${decryptedAccounts.length} decrypted accounts");
      return decryptedAccounts;
    } catch (e, stack) {
      print("Error getting all accounts: $e");
      print("Stack trace: $stack");
      rethrow;
    }
  }

  /// Get a specific account by ID
  Future<Account?> getAccountById(String id) async {
    final account = _accountBox.get(id);
    if (account == null) {
      return null;
    }

    try {
      final decryptedSecretKey = SecureStorageService.decrypt(
        account.secretKey,
      );
      return account.copyWith(secretKey: decryptedSecretKey);
    } catch (e) {
      // Return null if decryption fails
      return null;
    }
  }

  /// Save an account to storage
  Future<void> saveAccount(Account account) async {
    try {
      print("Saving account: ${account.issuer}");
      final encryptedSecretKey = SecureStorageService.encrypt(
        account.secretKey,
      );
      print("Secret key encrypted");
      final encryptedAccount = AccountModel.fromEntity(
        account.copyWith(secretKey: encryptedSecretKey),
      );
      print("Account model created");

      await _accountBox.put(account.id, encryptedAccount);
      print("Account saved to box with ID: ${account.id}");
    } catch (e, stack) {
      print("Error saving account: $e");
      print("Stack trace: $stack");
      rethrow;
    }
  }

  /// Delete an account from storage
  Future<void> deleteAccount(Account account) async {
    await _accountBox.delete(account.id);
  }
}
