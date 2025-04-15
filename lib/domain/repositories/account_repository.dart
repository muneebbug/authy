import 'package:sentinel/domain/entities/account.dart';

/// Repository interface for account management
abstract class AccountRepository {
  /// Get all accounts
  Future<List<Account>> getAllAccounts();

  /// Get a specific account by ID
  Future<Account?> getAccountById(String id);

  /// Add a new account
  Future<void> addAccount(Account account);

  /// Update an existing account
  Future<void> updateAccount(Account account);

  /// Delete an account by ID
  Future<void> deleteAccount(String id);

  /// Generate the current TOTP code for an account
  Future<String> generateCode(Account account);

  /// Get the remaining seconds until the next code rotation
  int getRemainingSeconds(Account account);
}
