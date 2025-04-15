import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:base32/base32.dart';
import 'package:sentinel/core/utils/totp_service.dart';
import 'package:sentinel/domain/entities/account.dart';
import 'package:sentinel/presentation/providers/account_provider.dart';
import 'package:sentinel/presentation/widgets/dot_pattern_background.dart';

/// Screen for adding a new TOTP account with Nothing OS-inspired design
class AddAccountScreen extends ConsumerStatefulWidget {
  const AddAccountScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends ConsumerState<AddAccountScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _issuerController = TextEditingController();
  final _accountNameController = TextEditingController();
  final _secretController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  // QR Scanner related
  bool _showQrScanner = true;
  late AnimationController _animationController;
  late Animation<double> _animation;
  MobileScannerController _scannerController = MobileScannerController();

  @override
  void initState() {
    super.initState();

    // Configure the scanning line animation
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.linear),
    );

    // Start the animation and make it repeat
    _animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _issuerController.dispose();
    _accountNameController.dispose();
    _secretController.dispose();
    _animationController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.primary;

    // Return QR Scanner or manual entry form based on state
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          _showQrScanner ? 'Scan QR Code' : 'Add Account',
          style: GoogleFonts.spaceMono(letterSpacing: 1.0),
        ),
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (_showQrScanner) {
              Navigator.of(context).pop();
            } else {
              setState(() {
                _showQrScanner = true;
              });
            }
          },
        ),
      ),
      body:
          _showQrScanner
              ? _buildQrScanner(accentColor)
              : _buildManualEntryForm(),
    );
  }

  /// Build the QR scanner view with a square marker and scanning line
  Widget _buildQrScanner(Color accentColor) {
    final size = MediaQuery.of(context).size;
    final scanArea = min(size.width, size.height) * 0.65;

    return Stack(
      children: [
        // Full-screen camera view
        MobileScanner(
          controller: _scannerController,
          onDetect: (capture) {
            final List<Barcode> barcodes = capture.barcodes;

            // Process the first valid barcode
            for (final barcode in barcodes) {
              if (barcode.rawValue != null) {
                _processQrCode(barcode.rawValue!);
                break;
              }
            }
          },
        ),

        // Dot pattern overlay
        const DotPatternBackground(opacity: 0.03),

        // Square frame overlay
        Center(
          child: Container(
            width: scanArea,
            height: scanArea,
            decoration: BoxDecoration(
              border: Border.all(color: accentColor, width: 2),
            ),
            child: Stack(
              children: [
                // Animated scanning line
                AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Positioned(
                      left: 0,
                      right: 0,
                      top: _animation.value * scanArea,
                      child: Container(height: 2, color: accentColor),
                    );
                  },
                ),
              ],
            ),
          ),
        ),

        // Manual entry button
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 40),
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _showQrScanner = false;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(color: Colors.grey.shade700),
                ),
              ),
              child: Text(
                'Manual Entry',
                style: GoogleFonts.spaceMono(letterSpacing: 1.0),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Process the QR code and extract account information
  void _processQrCode(String data) {
    try {
      // Parse the TOTP URI
      // Format: otpauth://totp/ISSUER:ACCOUNT?secret=SECRET&issuer=ISSUER
      final Uri uri = Uri.parse(data);

      if (uri.scheme != 'otpauth' || uri.host != 'totp') {
        throw Exception('Invalid QR code format');
      }

      // Extract the account info
      final path = uri.path.substring(1); // Remove leading '/'
      String issuer = '';
      String accountName = path;

      // If path has the format "Issuer:accountName"
      if (path.contains(':')) {
        final parts = path.split(':');
        issuer = parts[0];
        accountName = parts.length > 1 ? parts[1] : '';
      }

      // Get issuer from query param if available (takes precedence)
      if (uri.queryParameters.containsKey('issuer')) {
        issuer = uri.queryParameters['issuer']!;
      }

      // Get the secret
      final secret = uri.queryParameters['secret'] ?? '';

      if (secret.isEmpty) {
        throw Exception('No secret found in QR code');
      }

      // Set the form values
      setState(() {
        _issuerController.text = issuer;
        _accountNameController.text = accountName;
        _secretController.text = secret;
        _showQrScanner = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid QR code: ${e.toString()}'),
          backgroundColor: Colors.red.shade900,
        ),
      );
    }
  }

  /// Build the manual entry form view
  Widget _buildManualEntryForm() {
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.primary;

    return Stack(
      children: [
        // Dot pattern background
        const DotPatternBackground(),

        // Main content
        SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderText(),
                const SizedBox(height: 40),
                _buildTextField(
                  controller: _issuerController,
                  label: 'SERVICE NAME',
                  hint: 'Google, Twitter, GitHub...',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a service name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                _buildTextField(
                  controller: _accountNameController,
                  label: 'ACCOUNT',
                  hint: 'username or email@example.com',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter an account name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                _buildTextField(
                  controller: _secretController,
                  label: 'SECRET KEY',
                  hint: 'JBSWY3DPEHPK3PXP',
                  isSecret: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a secret key';
                    }
                    try {
                      // Validate by attempting to decode it
                      base32.decode(
                        value.replaceAll(RegExp(r'[^A-Za-z0-9]'), ''),
                      );
                      return null;
                    } catch (e) {
                      return 'Invalid secret key format';
                    }
                  },
                ),
                const SizedBox(height: 40),
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.red.shade900.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade900),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade400),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: GoogleFonts.spaceMono(
                              color: Colors.red.shade400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveAccount,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child:
                        _isLoading
                            ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                            : Text(
                              'SAVE ACCOUNT',
                              style: GoogleFonts.spaceMono(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Add new authenticator',
          style: GoogleFonts.spaceMono(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[300],
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter the details of your 2FA account',
          style: GoogleFonts.spaceMono(
            fontSize: 14,
            color: Colors.grey[500],
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool isSecret = false,
    String? Function(String?)? validator,
  }) {
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.spaceMono(
            fontSize: 12,
            color: Colors.grey[400],
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.spaceMono(color: Colors.grey[600]),
            filled: true,
            fillColor: theme.colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: accentColor, width: 1),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            suffixIcon:
                isSecret
                    ? IconButton(
                      icon: const Icon(Icons.content_paste, size: 20),
                      onPressed: _pasteFromClipboard,
                    )
                    : null,
          ),
          style: GoogleFonts.spaceMono(letterSpacing: 0.5),
          validator: validator,
        ),
      ],
    );
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null) {
      // Clean the secret (remove spaces and special chars)
      final cleanedSecret = data.text!.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
      _secretController.text = cleanedSecret;
    }
  }

  void _saveAccount() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        final secret = _secretController.text.trim().replaceAll(
          RegExp(r'[^A-Za-z0-9]'),
          '',
        );

        // Validate the secret can generate a code using a temporary Account object
        final tempAccount = Account(
          issuer: _issuerController.text.trim(),
          accountName: _accountNameController.text.trim(),
          secretKey: secret,
        );
        await TOTPService.generateCode(tempAccount);

        final account = Account(
          issuer: _issuerController.text.trim(),
          accountName: _accountNameController.text.trim(),
          secretKey: secret,
        );

        await ref.read(accountsProvider.notifier).addAccount(account);
        if (mounted) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'Error adding account: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }
}
