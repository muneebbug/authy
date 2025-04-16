import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sentinel/core/utils/auth_service.dart';
import 'package:sentinel/presentation/providers/auth_provider.dart';
import 'package:sentinel/presentation/widgets/dot_pattern_background.dart';

/// The different modes for the PIN screen
enum PinScreenMode {
  create, // First-time setup
  modify, // Change an existing PIN
  remove, // Remove an existing PIN
}

/// Screen for setting up PIN authentication
class PinSetupScreen extends ConsumerStatefulWidget {
  final PinScreenMode mode;

  const PinSetupScreen({Key? key, this.mode = PinScreenMode.create})
    : super(key: key);

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  final _confirmFocusNode = FocusNode();
  String _errorMessage = '';
  bool _isConfirming = false;
  String _firstPin = '';

  // Used for PIN modification flow
  bool _isVerifyingOldPin = false;
  bool _oldPinVerified = false;

  @override
  void initState() {
    super.initState();

    // If we're modifying or removing, we need to verify the old PIN first
    if (widget.mode == PinScreenMode.modify ||
        widget.mode == PinScreenMode.remove) {
      _isVerifyingOldPin = true;
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    _confirmFocusNode.dispose();
    super.dispose();
  }

  /// Verify the user's existing PIN
  Future<void> _verifyExistingPin() async {
    if (_pinController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your current PIN';
      });
      return;
    }

    final isValid = await AuthService.validatePin(_pinController.text);

    if (isValid) {
      setState(() {
        _isVerifyingOldPin = false;
        _oldPinVerified = true;
        _pinController.clear();
        _errorMessage = '';

        // If we're removing the PIN, we're done after verification
        if (widget.mode == PinScreenMode.remove) {
          _removePin();
        }
      });
    } else {
      setState(() {
        _errorMessage = 'Invalid PIN';
        _pinController.clear();
      });
    }
  }

  /// Remove PIN after successful verification
  Future<void> _removePin() async {
    try {
      await ref.read(authMethodProvider.notifier).removeAuthentication();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PIN has been removed'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to remove PIN: ${e.toString()}';
      });
    }
  }

  void _proceedToConfirmPin() {
    if (_pinController.text.length < 4) {
      setState(() {
        _errorMessage = 'PIN must be at least 4 digits';
      });
      return;
    }

    setState(() {
      _firstPin = _pinController.text;
      _isConfirming = true;
      _errorMessage = '';
      _pinController.clear();
    });

    // Focus on the confirmation field
    Future.delayed(const Duration(milliseconds: 100), () {
      _confirmFocusNode.requestFocus();
    });
  }

  Future<void> _savePin() async {
    if (_confirmPinController.text != _firstPin) {
      setState(() {
        _errorMessage = 'PINs do not match';
        _confirmPinController.clear();
      });
      return;
    }

    try {
      // Save the PIN
      await ref.read(authMethodProvider.notifier).setPin(_firstPin);

      // Show success and navigate back
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.mode == PinScreenMode.modify
                  ? 'PIN has been updated successfully'
                  : 'PIN has been set successfully',
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to set PIN: ${e.toString()}';
      });
    }
  }

  String _getScreenTitle() {
    if (_isVerifyingOldPin) {
      return 'VERIFY PIN';
    } else if (_isConfirming) {
      return 'CONFIRM PIN';
    } else {
      switch (widget.mode) {
        case PinScreenMode.create:
          return 'CREATE PIN';
        case PinScreenMode.modify:
          return 'NEW PIN';
        case PinScreenMode.remove:
          return 'REMOVE PIN';
      }
    }
  }

  String _getMainHeading() {
    if (_isVerifyingOldPin) {
      return widget.mode == PinScreenMode.remove
          ? 'Verify PIN to Remove'
          : 'Verify Your PIN';
    } else if (_isConfirming) {
      return 'Confirm PIN';
    } else {
      switch (widget.mode) {
        case PinScreenMode.create:
          return 'Create PIN';
        case PinScreenMode.modify:
          return 'Create New PIN';
        case PinScreenMode.remove:
          return 'Remove PIN';
      }
    }
  }

  String _getSubheading() {
    if (_isVerifyingOldPin) {
      return widget.mode == PinScreenMode.remove
          ? 'Enter your current PIN to confirm removal'
          : 'Enter your current PIN to continue';
    } else if (_isConfirming) {
      return 'Please re-enter your PIN to confirm';
    } else {
      switch (widget.mode) {
        case PinScreenMode.create:
          return 'Create a PIN to secure your accounts';
        case PinScreenMode.modify:
          return 'Enter a new PIN to replace your current one';
        case PinScreenMode.remove:
          return 'Confirm PIN removal';
      }
    }
  }

  String _getButtonLabel() {
    if (_isVerifyingOldPin) {
      return 'VERIFY';
    } else if (_isConfirming) {
      return 'CONFIRM';
    } else {
      return 'NEXT';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get current theme brightness
    final brightness = Theme.of(context).brightness;
    final isDarkMode = brightness == Brightness.dark;

    // Get colors based on current theme
    final primaryColor = Theme.of(context).primaryColor;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ??
        (isDarkMode ? Colors.white : Colors.black);
    final labelColor = isDarkMode ? Colors.white70 : Colors.black87;
    final borderColor = isDarkMode ? Colors.white54 : Colors.grey.shade400;
    final iconColor = isDarkMode ? Colors.white70 : Colors.black54;
    final surfaceColor = Theme.of(context).cardColor;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _getScreenTitle(),
          style: GoogleFonts.spaceMono(
            letterSpacing: 1.0,
            fontWeight: FontWeight.bold,
            color:
                Theme.of(context).appBarTheme.titleTextStyle?.color ??
                textColor,
          ),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, size: 24, color: textColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          // Background
          const DotPatternBackground(),

          // Use a solid background color instead of gradient for consistency
          Container(color: backgroundColor),

          // Main content
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  _isVerifyingOldPin
                      ? Icons.lock
                      : (_isConfirming ? Icons.check_circle : Icons.pin),
                  size: 64,
                  color: textColor,
                ),
                const SizedBox(height: 24),

                Text(
                  _getMainHeading(),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                Text(
                  _getSubheading(),
                  style: TextStyle(fontSize: 16, color: labelColor),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // PIN entry field
                TextField(
                  controller:
                      _isConfirming ? _confirmPinController : _pinController,
                  focusNode: _isConfirming ? _confirmFocusNode : null,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  obscureText: true,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText:
                        _isVerifyingOldPin
                            ? 'Enter Current PIN'
                            : (_isConfirming ? 'Confirm PIN' : 'Enter PIN'),
                    labelStyle: TextStyle(color: labelColor),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: primaryColor),
                    ),
                    prefixIcon: Icon(Icons.lock, color: iconColor),
                    counterStyle: TextStyle(color: labelColor),
                    filled: true,
                    fillColor: surfaceColor.withOpacity(0.5),
                  ),
                  style: TextStyle(color: textColor),
                  onSubmitted:
                      (_) =>
                          _isVerifyingOldPin
                              ? _verifyExistingPin()
                              : (_isConfirming
                                  ? _savePin()
                                  : _proceedToConfirmPin()),
                ),
                const SizedBox(height: 16),

                // Button with accent-colored style for better visibility
                ElevatedButton(
                  onPressed:
                      _isVerifyingOldPin
                          ? _verifyExistingPin
                          : (_isConfirming ? _savePin : _proceedToConfirmPin),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    elevation: 0, // No shadow
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    _getButtonLabel(),
                    style: GoogleFonts.spaceMono(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),

                // Error message
                if (_errorMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      _errorMessage,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // PIN security warning - only show for create/modify
                if (!_isVerifyingOldPin && widget.mode != PinScreenMode.remove)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: surfaceColor.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '⚠️ Important',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'If you forget your PIN, you will not be able to access your accounts. Make sure to remember it.',
                            style: TextStyle(fontSize: 14, color: labelColor),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
