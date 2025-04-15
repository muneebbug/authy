import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:authy/domain/entities/account.dart';
import 'package:authy/presentation/providers/account_provider.dart';
import 'package:authy/presentation/widgets/account_item.dart';
import 'package:authy/presentation/screens/add_account_screen.dart';
import 'package:authy/presentation/widgets/dot_pattern_background.dart';

/// Home screen that displays all accounts with Nothing OS design
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    // Watch the accounts list
    final accounts = ref.watch(accountsProvider);
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Home',
          style: TextStyle(fontFamily: 'SpaceMono', letterSpacing: 1.0),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {
              // TODO: Show more options menu
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Dot pattern background
          const DotPatternBackground(),
          // Main content
          _buildBody(accounts),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddAccount,
        child: const Icon(Icons.add, color: Colors.black),
        backgroundColor: accentColor,
      ),
    );
  }

  /// Build body based on the accounts state
  Widget _buildBody(List<Account> accounts) {
    if (accounts.isEmpty) {
      return _buildNothingStyleEmptyState();
    }
    return _buildAccountsList(accounts);
  }

  /// Build Nothing OS styled empty state when no accounts exist
  Widget _buildNothingStyleEmptyState() {
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.primary;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Dot matrix "no accounts" icon made of small Container dots
          Container(
            width: 100,
            height: 100,
            margin: const EdgeInsets.only(bottom: 24),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Lock icon made of dots
                ...List.generate(
                  16,
                  (index) => Positioned(
                    left: (index % 4) * 20.0 + 10,
                    top: (index ~/ 4) * 20.0 + 10,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ),
                // Highlighted dot in center
                Positioned(
                  top: 50,
                  left: 50,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accentColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Empty state text
          Text(
            'No accounts added yet',
            style: TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 16,
              color: Colors.grey[400],
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to add your first account',
            style: TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 14,
              color: Colors.grey[600],
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 32),
          OutlinedButton(
            onPressed: _navigateToAddAccount,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: accentColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              'ADD ACCOUNT',
              style: TextStyle(
                color: accentColor,
                fontFamily: 'SpaceMono',
                letterSpacing: 1.5,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build the list of accounts
  Widget _buildAccountsList(List<Account> accounts) {
    return RefreshIndicator(
      onRefresh: () async {
        // Refresh the accounts list
        await ref.read(accountsProvider.notifier).loadAccounts();
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
        itemCount: accounts.length,
        itemBuilder: (context, index) {
          final account = accounts[index];
          return Dismissible(
            key: Key(account.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                color: Colors.red.shade900,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.delete_outline, color: Colors.white),
            ),
            confirmDismiss: (direction) async {
              return await _confirmDeleteDialog(account);
            },
            onDismissed: (direction) {
              _deleteAccount(account);
            },
            child: AccountItem(
              account: account,
              onTap: () {
                // TODO: Show account details or copy code
              },
            ),
          );
        },
      ),
    );
  }

  /// Navigate to add account screen
  void _navigateToAddAccount() async {
    // Wait for the add account screen to complete, then refresh accounts
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const AddAccountScreen()));

    // Refresh the accounts list when returning
    if (mounted) {
      ref.read(accountsProvider.notifier).loadAccounts();
    }
  }

  /// Delete an account
  void _deleteAccount(Account account) {
    ref.read(accountsProvider.notifier).deleteAccount(account).catchError((
      error,
    ) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete account: $error'),
          backgroundColor: Colors.red.shade900,
        ),
      );
    });
  }

  /// Show confirmation dialog before deleting an account
  Future<bool> _confirmDeleteDialog(Account account) async {
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.primary;

    return await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              backgroundColor: theme.colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Delete Account',
                style: TextStyle(fontFamily: 'SpaceMono', letterSpacing: 0.5),
              ),
              content: Text(
                'Are you sure you want to delete ${account.issuer} (${account.accountName})?',
                style: const TextStyle(
                  fontFamily: 'SpaceMono',
                  letterSpacing: 0.3,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text(
                    'CANCEL',
                    style: TextStyle(
                      fontFamily: 'SpaceMono',
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(
                    'DELETE',
                    style: TextStyle(
                      color: Colors.red.shade400,
                      fontFamily: 'SpaceMono',
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;
  }
}
