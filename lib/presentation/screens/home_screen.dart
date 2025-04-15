import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:authy/domain/entities/account.dart';
import 'package:authy/presentation/providers/account_provider.dart';
import 'package:authy/presentation/widgets/account_item.dart';
import 'package:authy/presentation/screens/add_account_screen.dart';

/// Home screen that displays all accounts
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Authy'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // TODO: Navigate to settings screen
            },
          ),
        ],
      ),
      body: _buildBody(accounts),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddAccount,
        child: const Icon(Icons.add),
      ),
    );
  }

  /// Build body based on the accounts state
  Widget _buildBody(List<Account> accounts) {
    if (accounts.isEmpty) {
      return _buildEmptyState();
    }
    return _buildAccountsList(accounts);
  }

  /// Build empty state when no accounts exist
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.security, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'No accounts added yet',
            style: TextStyle(fontSize: 20, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to add your first account',
            style: TextStyle(fontSize: 16, color: Colors.grey[500]),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _navigateToAddAccount,
            icon: const Icon(Icons.add),
            label: const Text('ADD ACCOUNT'),
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
        padding: const EdgeInsets.only(bottom: 80), // Space for FAB
        itemCount: accounts.length,
        itemBuilder: (context, index) {
          final account = accounts[index];
          return Dismissible(
            key: Key(account.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              color: Colors.red,
              child: const Icon(Icons.delete, color: Colors.white),
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
          backgroundColor: Colors.red,
        ),
      );
    });
  }

  /// Show confirmation dialog before deleting an account
  Future<bool> _confirmDeleteDialog(Account account) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Delete Account'),
              content: Text(
                'Are you sure you want to delete ${account.issuer} (${account.accountName})?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('CANCEL'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text(
                    'DELETE',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;
  }
}
