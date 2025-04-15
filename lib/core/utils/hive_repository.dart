import 'package:hive/hive.dart';
import 'package:sentinel/domain/entities/account.dart';
import 'package:sentinel/data/models/account_model.dart';
import 'package:sentinel/core/utils/secure_storage_service.dart';
import 'package:sentinel/core/utils/logger_util.dart';

/// Repository for interacting with Hive storage
class HiveRepository {
  static const String _boxName = 'accounts';
  late Box<AccountModel> _accountBox;

  /// Initialize the repository
  Future<void> init() async {
    try {
      LoggerUtil.info("Initializing HiveRepository...");

      // Register adapter for AccountModel if not already registered
      if (!Hive.isAdapterRegistered(0)) {
        LoggerUtil.debug("Registering AccountModelAdapter");
        Hive.registerAdapter(AccountModelAdapter());
      }

      // Register adapter for Algorithm enum if not already registered
      if (!Hive.isAdapterRegistered(2)) {
        LoggerUtil.debug("Registering Algorithm enum adapter");
        Hive.registerAdapter(AlgorithmAdapter());
      }

      LoggerUtil.debug("Opening Hive box: $_boxName");
      _accountBox = await Hive.openBox<AccountModel>(_boxName);
      LoggerUtil.debug(
        "Hive box opened successfully, count: ${_accountBox.length}",
      );
    } catch (e, stack) {
      LoggerUtil.error("Error initializing HiveRepository", e, stack);
      rethrow;
    }
  }

  /// Get all accounts from storage
  Future<List<Account>> getAccounts() async {
    try {
      LoggerUtil.debug("Getting all accounts, count: ${_accountBox.length}");
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
          LoggerUtil.error("Error decrypting account", e);
          // Skip accounts with invalid encryption
          continue;
        }
      }

      LoggerUtil.debug(
        "Returned ${decryptedAccounts.length} decrypted accounts",
      );
      return decryptedAccounts;
    } catch (e, stack) {
      LoggerUtil.error("Error getting all accounts", e, stack);
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
      LoggerUtil.info("Saving account: ${account.issuer}");
      final encryptedSecretKey = SecureStorageService.encrypt(
        account.secretKey,
      );
      LoggerUtil.debug("Secret key encrypted");
      final encryptedAccount = AccountModel.fromEntity(
        account.copyWith(secretKey: encryptedSecretKey),
      );
      LoggerUtil.debug("Account model created");

      await _accountBox.put(account.id, encryptedAccount);
      LoggerUtil.debug("Account saved to box with ID: ${account.id}");
    } catch (e, stack) {
      LoggerUtil.error("Error saving account", e, stack);
      rethrow;
    }
  }

  /// Delete an account from storage
  Future<void> deleteAccount(Account account) async {
    await _accountBox.delete(account.id);
  }
}
