import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sentinel/core/theme/app_theme.dart';
import 'package:sentinel/core/utils/secure_export_service.dart';
import 'package:sentinel/domain/entities/account.dart';
import 'package:sentinel/presentation/providers/account_provider.dart';
import 'package:sentinel/presentation/widgets/dot_pattern_background.dart';
import 'package:path_provider/path_provider.dart';

/// Screen for importing accounts
class ImportAccountsScreen extends ConsumerStatefulWidget {
  const ImportAccountsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ImportAccountsScreen> createState() =>
      _ImportAccountsScreenState();
}

class _ImportAccountsScreenState extends ConsumerState<ImportAccountsScreen> {
  final _passphraseController = TextEditingController();
  String? _selectedFilePath;
  String _selectedFileName = '';

  bool _isLoading = false;
  bool _isComplete = false;
  String? _errorMessage;
  int _importedAccountsCount = 0;
  int _duplicateAccountsCount = 0;

  @override
  void dispose() {
    _passphraseController.dispose();
    super.dispose();
  }

  Future<void> _selectFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        dialogTitle: 'Select Sentinel Export File (.sav)',
        allowCompression: false,
        lockParentWindow: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFilePath = result.files.single.path;
          _selectedFileName = result.files.single.name;
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to select file: $e';
      });
    }
  }

  Future<void> _importAccounts() async {
    if (_selectedFilePath == null) {
      setState(() {
        _errorMessage = 'Please select a file first';
      });
      return;
    }

    if (_passphraseController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter the passphrase';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final passphrase = _passphraseController.text;

      // Use SecureExportService to decrypt and import accounts
      final List<Account> importedAccounts =
          await SecureExportService.importAccounts(
            _selectedFilePath!,
            passphrase,
          );

      final accountProvider = ref.read(accountsProvider.notifier);
      // Get existing accounts to check for duplicates
      final existingAccounts = ref.read(accountsProvider);

      int importCount = 0;
      int duplicateCount = 0;

      for (var account in importedAccounts) {
        try {
          // Check if account already exists (by ID or by issuer+account combination)
          bool isDuplicate = existingAccounts.any(
            (existing) =>
                existing.id == account.id ||
                (existing.issuer == account.issuer &&
                    existing.accountName == account.accountName &&
                    existing.secretKey == account.secretKey),
          );

          if (isDuplicate) {
            duplicateCount++;
            continue; // Skip duplicate account
          }

          await accountProvider.addAccount(account);
          importCount++;
        } catch (e) {
          print('Failed to import account: $e');
        }
      }

      setState(() {
        _isLoading = false;
        _isComplete = true;
        _importedAccountsCount = importCount;
        _duplicateAccountsCount = duplicateCount;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        // Provide a user-friendly error message
        if (e.toString().contains('decrypt') ||
            e.toString().contains('Invalid export file format') ||
            e.toString().contains('Failed to import')) {
          _errorMessage =
              'Incorrect passphrase or invalid export file format. Please check your passphrase and try again.';
        } else {
          _errorMessage = 'Import failed: ${e.toString()}';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColorIndex = ref.watch(accentColorProvider);
    final accentColor = AppTheme.getAccentColor(accentColorIndex);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'IMPORT ACCOUNTS',
          style: GoogleFonts.spaceMono(
            letterSpacing: 1.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 24),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          // Background
          const DotPatternBackground(),

          // Content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child:
                  _isLoading
                      ? _buildLoadingState()
                      : _isComplete
                      ? _buildCompleteView()
                      : _buildImportForm(),
            ),
          ),
        ],
      ),
    );
  }

  /// Build the import form state widget
  Widget _buildImportForm() {
    final theme = Theme.of(context);
    final accentColorIndex = ref.watch(accentColorProvider);
    final accentColor = AppTheme.getAccentColor(accentColorIndex);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Import from Backup', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 20),

          // File Selection
          Text('Select Backup File', style: theme.textTheme.titleMedium),
          const SizedBox(height: 10),
          InkWell(
            onTap: _selectFile,
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outline),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.file_present, color: theme.colorScheme.primary),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Text(
                      _selectedFileName.isEmpty
                          ? 'No file selected'
                          : _selectedFileName,
                      style: theme.textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.upload_file, color: theme.colorScheme.primary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),

          // Passphrase Input
          Text('Passphrase (Required)', style: theme.textTheme.titleMedium),
          const SizedBox(height: 10),
          TextField(
            controller: _passphraseController,
            decoration: InputDecoration(
              hintText: 'Enter passphrase',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              prefixIcon: const Icon(Icons.lock_outline),
            ),
            obscureText: true,
          ),

          // Error Message
          if (_errorMessage != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 40),
          Center(
            child: ElevatedButton(
              onPressed: _importAccounts,
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: AppTheme.getTextColor(accentColor),
                minimumSize: const Size(250, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('IMPORT ACCOUNTS'),
            ),
          ),
        ],
      ),
    );
  }

  /// Build the loading state widget
  Widget _buildLoadingState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 24),
        Text(
          'Importing your accounts...',
          style: GoogleFonts.spaceMono(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Please wait while we decrypt and import your accounts.',
          style: GoogleFonts.spaceMono(fontSize: 14, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// Build the import complete state widget
  Widget _buildCompleteView() {
    final theme = Theme.of(context);
    final accentColorIndex = ref.watch(accentColorProvider);
    final accentColor = AppTheme.getAccentColor(accentColorIndex);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle_outline,
              size: 80,
              color: Colors.green,
            ),
            const SizedBox(height: 20),
            Text('Import Complete', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 10),
            Text(
              'Successfully imported $_importedAccountsCount accounts.',
              textAlign: TextAlign.center,
            ),

            // Show duplicate accounts message if any were found
            if (_duplicateAccountsCount > 0) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$_duplicateAccountsCount duplicate ${_duplicateAccountsCount == 1 ? 'account was' : 'accounts were'} skipped.',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],

            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: AppTheme.getTextColor(accentColor),
                minimumSize: const Size(200, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('DONE'),
            ),
          ],
        ),
      ),
    );
  }
}
