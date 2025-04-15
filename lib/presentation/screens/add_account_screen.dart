import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:base32/base32.dart';
import 'package:authy/domain/entities/account.dart';
import 'package:authy/presentation/providers/account_provider.dart';

/// Screen for adding a new 2FA account
class AddAccountScreen extends ConsumerStatefulWidget {
  const AddAccountScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends ConsumerState<AddAccountScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;

  // Form fields
  final _issuerController = TextEditingController();
  final _accountNameController = TextEditingController();
  final _secretKeyController = TextEditingController();

  // Fixed defaults (Google Authenticator standard)
  final Algorithm _algorithm = Algorithm.sha1;
  final int _digits = 6;
  final int _period = 30;

  // Random color selection
  final List<int> _colorOptions = [
    0xFF2196F3, // Blue
    0xFFF44336, // Red
    0xFF4CAF50, // Green
    0xFFFF9800, // Orange
    0xFF9C27B0, // Purple
    0xFF795548, // Brown
  ];
  late int _colorCode;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Select a random color
    _colorCode =
        _colorOptions[DateTime.now().microsecond % _colorOptions.length];
  }

  @override
  void dispose() {
    _tabController.dispose();
    _issuerController.dispose();
    _accountNameController.dispose();
    _secretKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Account'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.qr_code), text: 'Scan QR'),
            Tab(icon: Icon(Icons.edit), text: 'Manual Entry'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildQRScanner(), _buildManualEntryForm()],
      ),
    );
  }

  /// QR Scanner view
  Widget _buildQRScanner() {
    return Column(
      children: [
        Expanded(
          child: MobileScanner(
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                _processQRCode(barcodes.first.rawValue ?? '');
              }
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Scan a QR code to add a new account',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ),
      ],
    );
  }

  /// Manual entry form
  Widget _buildManualEntryForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _issuerController,
              decoration: const InputDecoration(
                labelText: 'Service Name',
                hintText: 'Google, Twitter, etc.',
                prefixIcon: Icon(Icons.business),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a service name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _accountNameController,
              decoration: const InputDecoration(
                labelText: 'Account',
                hintText: 'username or email',
                prefixIcon: Icon(Icons.account_circle),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an account name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _secretKeyController,
              decoration: const InputDecoration(
                labelText: 'Secret Key',
                hintText: 'JBSWY3DPEHPK3PXP',
                prefixIcon: Icon(Icons.key),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a secret key';
                }

                // Check if it's a valid base32 string
                try {
                  base32.decode(value.replaceAll(' ', ''));
                } catch (e) {
                  return 'Invalid base32 secret key';
                }

                return null;
              },
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _submitForm,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('ADD ACCOUNT'),
            ),
          ],
        ),
      ),
    );
  }

  /// Process a QR code from the scanner
  void _processQRCode(String data) {
    print("Processing QR code: $data");
    // Handle otpauth URI format: otpauth://totp/ISSUER:ACCOUNT?secret=SECRET&issuer=ISSUER&algorithm=SHA1&digits=6&period=30
    if (data.startsWith('otpauth://totp/')) {
      try {
        final Uri uri = Uri.parse(data);

        // Parse label (ISSUER:ACCOUNT)
        final String label = Uri.decodeComponent(uri.path.substring(1));
        String issuer = '';
        String account = label;

        if (label.contains(':')) {
          final parts = label.split(':');
          issuer = parts[0];
          account = parts[1];
        }

        // Override issuer if present in parameters
        if (uri.queryParameters.containsKey('issuer')) {
          issuer = uri.queryParameters['issuer']!;
        }

        final String secret = uri.queryParameters['secret'] ?? '';

        if (secret.isEmpty) {
          _showError('QR code missing secret key');
          return;
        }

        // Validate secret is a valid base32 string
        try {
          base32.decode(secret.replaceAll(' ', ''));
        } catch (e) {
          _showError('Invalid secret key format');
          return;
        }

        // Create and add the account directly
        final newAccount = Account(
          issuer: issuer,
          accountName: account,
          secretKey: secret.replaceAll(' ', ''),
          algorithm: _algorithm,
          digits: _digits,
          period: _period,
          colorCode: _colorCode,
        );

        print(
          "Account created from QR: ${newAccount.issuer}, Secret: ${newAccount.secretKey}",
        );

        // Show a loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return const AlertDialog(
              content: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 20),
                  Text("Adding account..."),
                ],
              ),
            );
          },
        );

        // Add the account and return to home screen
        ref
            .read(accountsProvider.notifier)
            .addAccount(newAccount)
            .then((_) {
              print("Account added successfully from QR");
              // Close the loading dialog
              Navigator.of(context).pop();
              // Return to home
              Navigator.of(context).pop();
            })
            .catchError((error) {
              // Close the loading dialog
              Navigator.of(context).pop();
              print("Error adding account from QR: $error");
              _showError('Failed to add account: $error');
            });
      } catch (e) {
        _showError('Invalid QR code format');
      }
    } else {
      _showError('Unsupported QR code format');
    }
  }

  /// Submit the form to add a new account
  void _submitForm() {
    print("Submit form called");
    if (_formKey.currentState!.validate()) {
      print("Form validated");
      final account = Account(
        issuer: _issuerController.text,
        accountName: _accountNameController.text,
        secretKey: _secretKeyController.text.replaceAll(' ', ''),
        algorithm: _algorithm,
        digits: _digits,
        period: _period,
        colorCode: _colorCode,
      );

      print("Account created: ${account.issuer}, Secret: ${account.secretKey}");

      ref
          .read(accountsProvider.notifier)
          .addAccount(account)
          .then((_) {
            print("Account added successfully");
            Navigator.of(context).pop();
          })
          .catchError((error) {
            print("Error adding account: $error");
            _showError('Failed to add account: $error');
          });
    } else {
      print("Form validation failed");
    }
  }

  /// Show error message
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}
