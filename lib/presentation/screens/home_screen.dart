import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
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
        title: Text('Home', style: GoogleFonts.spaceMono(letterSpacing: 1.0)),
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
            style: GoogleFonts.spaceMono(
              fontSize: 16,
              color: Colors.grey[400],
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to add your first account',
            style: GoogleFonts.spaceMono(
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
              style: GoogleFonts.spaceMono(
                color: accentColor,
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
          return AccountItem(
            account: account,
            onTap: () {
              // Copy the code to clipboard
              _copyTOTPCode(account);
            },
            onLongPress: () {
              // Show bottom sheet with options
              _showAccountOptionsSheet(account);
            },
          );
        },
      ),
    );
  }

  /// Copy the TOTP code to clipboard
  void _copyTOTPCode(Account account) async {
    // Show loading indicator
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Text('Copying code...'),
        duration: Duration(milliseconds: 300),
      ),
    );

    try {
      // Generate code
      final code = await ref
          .read(accountsProvider.notifier)
          .generateCode(account);

      // Copy to clipboard
      await Clipboard.setData(ClipboardData(text: code));

      if (mounted) {
        // Show success message with NothingOS style
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Code copied to clipboard',
                  style: GoogleFonts.spaceMono(color: Colors.white),
                ),
              ],
            ),
            backgroundColor: Colors.grey.shade900,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // Show error message
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Failed to copy code: $e'),
            backgroundColor: Colors.red.shade900,
          ),
        );
      }
    }
  }

  /// Show bottom sheet with account options in NothingOS style
  void _showAccountOptionsSheet(Account account) {
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.primary;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            border: Border.all(color: Colors.grey.shade800, width: 1),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Sheet handle
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 16),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade600,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Account info
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      // Account icon
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _getColorForAccount(account),
                            width: 1.0,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            account.issuer.isEmpty
                                ? '?'
                                : account.issuer[0].toUpperCase(),
                            style: TextStyle(
                              color: _getColorForAccount(account),
                              fontSize: 16,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Account details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              account.issuer,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              account.accountName,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[400],
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(color: Colors.grey, height: 1, thickness: 0.5),

                // Options
                _buildOptionTile(
                  icon: Icons.copy,
                  label: 'Copy Code',
                  onTap: () {
                    Navigator.pop(context);
                    _copyTOTPCode(account);
                  },
                  accentColor: accentColor,
                ),

                _buildOptionTile(
                  icon: Icons.delete_outline,
                  label: 'Delete Account',
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDeleteAccount(account);
                  },
                  destructive: true,
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Build an option tile for the bottom sheet
  Widget _buildOptionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? accentColor,
    bool destructive = false,
  }) {
    final color = destructive ? Colors.red.shade400 : accentColor;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 16),
            Text(
              label,
              style: GoogleFonts.spaceMono(
                fontSize: 16,
                color: destructive ? Colors.red.shade400 : Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Get color for account avatar based on issuer name
  Color _getColorForAccount(Account account) {
    // Select dot color based on issuer name (first letter) for variety
    switch (account.issuer.toLowerCase().isEmpty
        ? 'x'
        : account.issuer.toLowerCase()[0]) {
      case 'a':
      case 'b':
      case 'c':
        return Colors.blue;
      case 'd':
      case 'e':
      case 'f':
        return Colors.pink;
      case 'g':
      case 'h':
      case 'i':
        return Colors.amber;
      case 'j':
      case 'k':
      case 'l':
        return Colors.green;
      case 'm':
      case 'n':
      case 'o':
        return Colors.purple;
      case 'p':
      case 'q':
      case 'r':
        return Colors.red;
      case 's':
      case 't':
      case 'u':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  /// Confirm and delete an account
  void _confirmDeleteAccount(Account account) async {
    final shouldDelete = await _confirmDeleteDialog(account);
    if (shouldDelete && mounted) {
      _deleteAccount(account);
    }
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
              title: Text(
                'Delete Account',
                style: GoogleFonts.spaceMono(letterSpacing: 0.5),
              ),
              content: Text(
                'Are you sure you want to delete ${account.issuer} (${account.accountName})?',
                style: GoogleFonts.spaceMono(letterSpacing: 0.3),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    'CANCEL',
                    style: GoogleFonts.spaceMono(letterSpacing: 1.0),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(
                    'DELETE',
                    style: GoogleFonts.spaceMono(
                      color: Colors.red.shade400,
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
