import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:authy/domain/entities/account.dart';
import 'package:authy/domain/repositories/account_repository.dart';
import 'package:authy/core/utils/hive_repository.dart';
import 'package:authy/core/utils/totp_service.dart';
import 'package:authy/core/providers/totp_service_provider.dart';

/// Provider for account repository
final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  throw UnimplementedError('Repository must be initialized first');
});

/// Provider for the Hive repository
final hiveRepositoryProvider = Provider<HiveRepository>((ref) {
  return HiveRepository();
});

/// Provider for all accounts
final accountsProvider = StateNotifierProvider<AccountsNotifier, List<Account>>(
  (ref) {
    final repository = ref.watch(hiveRepositoryProvider);
    return AccountsNotifier(repository);
  },
);

/// Provider to track account loading state
final accountsLoadingProvider = StateProvider<bool>((ref) => true);

/// Provider for the selected account
final selectedAccountIdProvider = StateProvider<String?>((ref) => null);

/// Provider for the selected account details
final selectedAccountProvider = Provider<Account?>((ref) {
  final selectedId = ref.watch(selectedAccountIdProvider);
  final accounts = ref.watch(accountsProvider);

  if (selectedId == null) return null;
  try {
    return accounts.firstWhere((account) => account.id == selectedId);
  } catch (_) {
    return null;
  }
});

/// Provider for the TOTP code for a specific account
final totpCodeProvider = FutureProvider.family<String, Account>((
  ref,
  account,
) async {
  try {
    // Update the last used timestamp
    final updatedAccount = account.copyWith(lastUsedAt: DateTime.now());
    ref.read(accountsProvider.notifier).updateAccount(updatedAccount);

    // Generate the TOTP code
    return TOTPService.generateCode(account);
  } catch (e) {
    print("Error generating TOTP code: $e");
    rethrow;
  }
});

/// Current timestamp provider to force refresh of time-dependent providers
final currentTimestampProvider = StateProvider<int>((ref) {
  return DateTime.now().millisecondsSinceEpoch ~/ 1000;
});

/// Provider for the remaining seconds in the current period
final remainingSecondsProvider = Provider.family<int, Account>((ref, account) {
  // Read from the timestamp provider to ensure this provider refreshes
  ref.watch(currentTimestampProvider);
  return TOTPService.getRemainingSeconds(account);
});

/// Notifier for managing accounts
class AccountsNotifier extends StateNotifier<List<Account>> {
  final HiveRepository _repository;
  bool _isInitialized = false;

  /// Constructor
  AccountsNotifier(this._repository) : super([]) {
    _initializeRepository();
  }

  bool get isInitialized => _isInitialized;

  /// Initialize the repository and load accounts
  Future<void> _initializeRepository() async {
    await _repository.init();

    // Only perform initial load if not already initialized
    if (!_isInitialized) {
      await loadAccounts();
      _isInitialized = true;
    }
  }

  /// Load accounts from storage
  Future<void> loadAccounts() async {
    // Skip if already have accounts
    if (state.isNotEmpty) {
      return;
    }

    try {
      final accounts = await _repository.getAccounts();

      // Only update state if we actually have new accounts or no accounts at all yet
      if (accounts.isNotEmpty || state.isEmpty) {
        state = accounts;
      }
    } catch (e) {
      print("Error loading accounts: $e");
      // Only set empty state if we don't already have accounts
      if (state.isEmpty) {
        state = [];
      }
    }
  }

  /// Add a new account
  Future<void> addAccount(Account account) async {
    await _repository.saveAccount(account);
    state = [...state, account];
  }

  /// Update an existing account
  Future<void> updateAccount(Account account) async {
    await _repository.saveAccount(account);
    state = state.map((a) => a.id == account.id ? account : a).toList();
  }

  /// Delete an account
  Future<void> deleteAccount(Account account) async {
    await _repository.deleteAccount(account);
    state = state.where((a) => a.id != account.id).toList();
  }

  /// Generate a TOTP code for an account
  Future<String> generateCode(Account account) async {
    // Update the last used timestamp
    final updatedAccount = account.copyWith(lastUsedAt: DateTime.now());
    await updateAccount(updatedAccount);

    // Generate the TOTP code
    return TOTPService.generateCode(account);
  }
}

/// Notifier for legacy account management (for backward compatibility)
class AccountNotifier extends StateNotifier<AsyncValue<void>> {
  final AccountsNotifier _accountsNotifier;

  AccountNotifier(this._accountsNotifier) : super(const AsyncValue.data(null));

  /// Delete an account by ID
  Future<void> deleteAccount(String id) async {
    state = const AsyncValue.loading();
    try {
      // Find the account by ID
      final account = _accountsNotifier.state.firstWhere(
        (account) => account.id == id,
        orElse: () => throw Exception('Account not found'),
      );

      // Delete the account
      await _accountsNotifier.deleteAccount(account);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

/// Provider for backward compatibility with AccountNotifier
final accountNotifierProvider =
    StateNotifierProvider<AccountNotifier, AsyncValue<void>>((ref) {
      final accountsNotifier = ref.watch(accountsProvider.notifier);
      return AccountNotifier(accountsNotifier);
    });
