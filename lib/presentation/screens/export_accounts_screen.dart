import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sentinel/core/theme/app_theme.dart';
import 'package:sentinel/core/utils/secure_export_service.dart';
import 'package:sentinel/presentation/providers/account_provider.dart';
import 'package:sentinel/presentation/widgets/dot_pattern_background.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Screen for exporting accounts
class ExportAccountsScreen extends ConsumerStatefulWidget {
  const ExportAccountsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ExportAccountsScreen> createState() =>
      _ExportAccountsScreenState();
}

class _ExportAccountsScreenState extends ConsumerState<ExportAccountsScreen> {
  bool _isExporting = false;
  bool _exportComplete = false;
  String _passphrase = '';
  String _filePath = '';
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _startExport();
  }

  /// Start the export process
  Future<void> _startExport() async {
    setState(() {
      _isExporting = true;
      _errorMessage = '';
    });

    try {
      // Get all accounts
      final accounts = ref.read(accountsProvider);

      if (accounts.isEmpty) {
        setState(() {
          _errorMessage = 'No accounts to export';
          _isExporting = false;
        });
        return;
      }

      // Export accounts
      final result = await SecureExportService.exportAccounts(accounts);

      setState(() {
        _passphrase = result['passphrase']!;
        _filePath = result['filePath']!;
        _exportComplete = true;
        _isExporting = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Export failed: ${e.toString()}';
        _isExporting = false;
      });
    }
  }

  /// Share the exported file
  Future<void> _shareFile() async {
    try {
      final file = File(_filePath);
      if (await file.exists()) {
        // Create a shareable copy with a recognizable name
        final directory = await getApplicationDocumentsDirectory();
        final fileName =
            'sentinel_export_${DateTime.now().millisecondsSinceEpoch}.sav';
        final newPath = '${directory.path}/$fileName';

        // Copy the file to ensure we have the right permissions
        final newFile = await file.copy(newPath);

        // Share the file using share_plus
        final result = await Share.shareXFiles(
          [XFile(newFile.path)],
          subject: 'Sentinel Accounts Export',
          text: 'Securely encrypted account export. Keep the passphrase safe!',
        );

        // Check if sharing was successful
        if (result.status == ShareResultStatus.dismissed ||
            result.status == ShareResultStatus.unavailable) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'File saved to: $newPath\nPlease use your file manager to share it.',
              ),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } else {
        setState(() {
          _errorMessage = 'Export file not found';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Sharing failed: ${e.toString()}';
      });
    }
  }

  /// Copy passphrase to clipboard
  void _copyPassphrase() {
    Clipboard.setData(ClipboardData(text: _passphrase));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Passphrase copied to clipboard'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColorIndex = ref.watch(accentColorProvider);
    final accentColor = AppTheme.getAccentColor(accentColorIndex);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'EXPORT ACCOUNTS',
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
                  _isExporting
                      ? _buildLoadingState()
                      : _errorMessage.isNotEmpty
                      ? _buildErrorState()
                      : _buildExportCompleteState(accentColor),
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
          'Exporting your accounts...',
          style: GoogleFonts.spaceMono(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Please wait while we securely encrypt your accounts.',
          style: GoogleFonts.spaceMono(fontSize: 14, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// Build the error state widget
  Widget _buildErrorState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
        const SizedBox(height: 24),
        Text(
          'Export Failed',
          style: GoogleFonts.spaceMono(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          _errorMessage,
          style: GoogleFonts.spaceMono(fontSize: 14, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _startExport,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            elevation: 0,
            minimumSize: const Size(200, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text('TRY AGAIN'),
        ),
      ],
    );
  }

  /// Build the export complete state widget
  Widget _buildExportCompleteState(Color accentColor) {
    final words = _passphrase.split(' ');
    final onAccentColor = AppTheme.getTextColor(accentColor);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
        const SizedBox(height: 24),
        Text(
          'Export Complete!',
          style: GoogleFonts.spaceMono(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Your accounts have been exported securely. Here\'s your passphrase:',
          style: GoogleFonts.spaceMono(fontSize: 14, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

        // Passphrase display
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accentColor.withOpacity(0.5)),
          ),
          child: Column(
            children: [
              Text(
                'RECOVERY PASSPHRASE',
                style: GoogleFonts.spaceMono(
                  fontSize: 12,
                  color: accentColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              // Passphrase words in a grid
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: List.generate(
                  words.length,
                  (index) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accentColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      words[index],
                      style: GoogleFonts.spaceMono(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _copyPassphrase,
                icon: const Icon(Icons.copy),
                label: const Text('COPY PASSPHRASE'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'IMPORTANT: Write down this passphrase in a safe place. It\'s required to import your accounts.',
          style: GoogleFonts.spaceMono(
            fontSize: 12,
            color: Colors.orange,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _shareFile,
          icon: const Icon(Icons.share),
          label: const Text('SHARE EXPORT FILE'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            elevation: 0,
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }
}
