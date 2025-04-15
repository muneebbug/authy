import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sentinel/presentation/providers/auth_provider.dart';
import 'package:sentinel/presentation/widgets/dot_pattern_background.dart';

/// Screen for setting up PIN authentication
class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({Key? key}) : super(key: key);

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

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    _confirmFocusNode.dispose();
    super.dispose();
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
          const SnackBar(
            content: Text('PIN has been set successfully'),
            backgroundColor: Colors.green,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isConfirming ? 'CONFIRM PIN' : 'CREATE PIN',
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

          // Gradient overlay for better contrast
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Theme.of(context).primaryColor.withOpacity(0.2),
                  Theme.of(context).primaryColor.withOpacity(0.1),
                ],
              ),
            ),
          ),

          // Main content
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.pin, size: 64, color: Colors.white),
                const SizedBox(height: 24),

                Text(
                  _isConfirming ? 'Confirm PIN' : 'Create PIN',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                Text(
                  _isConfirming
                      ? 'Please re-enter your PIN to confirm'
                      : 'Create a PIN to secure your accounts',
                  style: const TextStyle(fontSize: 16, color: Colors.white70),
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
                    labelText: _isConfirming ? 'Confirm PIN' : 'Enter PIN',
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white54),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white),
                    ),
                    prefixIcon: const Icon(Icons.lock, color: Colors.white70),
                    counterStyle: const TextStyle(color: Colors.white54),
                  ),
                  style: const TextStyle(color: Colors.white),
                  onSubmitted:
                      (_) =>
                          _isConfirming ? _savePin() : _proceedToConfirmPin(),
                ),
                const SizedBox(height: 16),

                // Button
                ElevatedButton(
                  onPressed: _isConfirming ? _savePin : _proceedToConfirmPin,
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.black,
                    backgroundColor: Theme.of(context).primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    _isConfirming ? 'CONFIRM' : 'NEXT',
                    style: GoogleFonts.spaceMono(fontWeight: FontWeight.bold),
                  ),
                ),

                // Error message
                if (_errorMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                const SizedBox(height: 24),

                // Additional info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        '⚠️ Important',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'If you forget your PIN, you will not be able to access your accounts. Make sure to remember it.',
                        style: TextStyle(fontSize: 14, color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                    ],
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
