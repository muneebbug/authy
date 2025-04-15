import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:base32/base32.dart';
import 'package:authy/core/utils/totp_service.dart';
import 'package:authy/domain/entities/account.dart';
import 'package:authy/presentation/providers/account_provider.dart';
import 'package:authy/presentation/widgets/dot_pattern_background.dart';

/// Screen for adding a new TOTP account with Nothing OS-inspired design
class AddAccountScreen extends ConsumerStatefulWidget {
  const AddAccountScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends ConsumerState<AddAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _issuerController = TextEditingController();
  final _accountNameController = TextEditingController();
  final _secretController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _issuerController.dispose();
    _accountNameController.dispose();
    _secretController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Add Account',
          style: TextStyle(fontFamily: 'SpaceMono', letterSpacing: 1.0),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
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
                              style: TextStyle(
                                color: Colors.red.shade400,
                                fontFamily: 'SpaceMono',
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
                              : const Text(
                                'SAVE ACCOUNT',
                                style: TextStyle(
                                  fontFamily: 'SpaceMono',
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
      ),
    );
  }

  Widget _buildHeaderText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Add new authenticator',
          style: TextStyle(
            fontFamily: 'SpaceMono',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[300],
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter the details of your 2FA account',
          style: TextStyle(
            fontFamily: 'SpaceMono',
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
          style: TextStyle(
            fontFamily: 'SpaceMono',
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
            hintStyle: TextStyle(
              color: Colors.grey[600],
              fontFamily: 'SpaceMono',
            ),
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
          style: const TextStyle(fontFamily: 'SpaceMono', letterSpacing: 0.5),
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
