import 'package:flutter/material.dart';
import 'package:authy/core/utils/auth_service.dart';

/// Screen for authenticating the user with PIN or biometric
class AuthScreen extends StatefulWidget {
  final Widget child;

  const AuthScreen({Key? key, required this.child}) : super(key: key);

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isAuthenticated = false;
  bool _isBiometricAvailable = false;
  AuthMethod _authMethod = AuthMethod.none;
  final _pinController = TextEditingController();
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initAuth();
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  /// Initialize authentication
  Future<void> _initAuth() async {
    final authMethod = await AuthService.getAuthMethod();
    final biometricAvailable = await AuthService.isBiometricAvailable();

    setState(() {
      _authMethod = authMethod;
      _isBiometricAvailable = biometricAvailable;
    });

    // If no authentication is required, proceed directly
    if (_authMethod == AuthMethod.none) {
      setState(() {
        _isAuthenticated = true;
      });
      return;
    }

    // If biometric auth is enabled, try it immediately
    if (_authMethod == AuthMethod.biometric) {
      _authenticateWithBiometrics();
    }
  }

  /// Authenticate with PIN
  Future<void> _authenticateWithPin() async {
    if (_pinController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your PIN';
      });
      return;
    }

    final isValid = await AuthService.validatePin(_pinController.text);

    if (isValid) {
      setState(() {
        _isAuthenticated = true;
        _errorMessage = '';
      });
    } else {
      setState(() {
        _errorMessage = 'Invalid PIN';
        _pinController.clear();
      });
    }
  }

  /// Authenticate with biometrics
  Future<void> _authenticateWithBiometrics() async {
    final isAuthenticated = await AuthService.authenticateWithBiometrics();

    setState(() {
      _isAuthenticated = isAuthenticated;
      if (!isAuthenticated) {
        _errorMessage = 'Biometric authentication failed';
      } else {
        _errorMessage = '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // If already authenticated, show the child
    if (_isAuthenticated) {
      return widget.child;
    }

    // Otherwise, show the auth screen
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).primaryColor,
              Theme.of(context).primaryColor.withOpacity(0.6),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.security, size: 80, color: Colors.white),
                  const SizedBox(height: 24),
                  const Text(
                    'Authentication Required',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please authenticate to access your accounts',
                    style: TextStyle(fontSize: 16, color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Show PIN entry if PIN auth is enabled
                  if (_authMethod == AuthMethod.pin) _buildPinAuthUI(),

                  // Show biometric button if available
                  if (_authMethod == AuthMethod.biometric &&
                      _isBiometricAvailable)
                    _buildBiometricAuthUI(),

                  if (_errorMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        _errorMessage,
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Build PIN authentication UI
  Widget _buildPinAuthUI() {
    return Column(
      children: [
        TextField(
          controller: _pinController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Enter PIN',
            labelStyle: TextStyle(color: Colors.white70),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white54),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white),
            ),
            prefixIcon: Icon(Icons.pin, color: Colors.white70),
            counterStyle: TextStyle(color: Colors.white54),
          ),
          style: const TextStyle(color: Colors.white),
          onSubmitted: (_) => _authenticateWithPin(),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _authenticateWithPin,
          style: ElevatedButton.styleFrom(
            foregroundColor: Theme.of(context).primaryColor,
            backgroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          ),
          child: const Text('UNLOCK'),
        ),

        // Show biometric option if available
        if (_isBiometricAvailable)
          TextButton.icon(
            onPressed: _authenticateWithBiometrics,
            icon: const Icon(Icons.fingerprint, color: Colors.white70),
            label: const Text(
              'Use Biometrics',
              style: TextStyle(color: Colors.white70),
            ),
          ),
      ],
    );
  }

  /// Build biometric authentication UI
  Widget _buildBiometricAuthUI() {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: _authenticateWithBiometrics,
          style: ElevatedButton.styleFrom(
            foregroundColor: Theme.of(context).primaryColor,
            backgroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          ),
          icon: const Icon(Icons.fingerprint),
          label: const Text('AUTHENTICATE WITH BIOMETRICS'),
        ),
      ],
    );
  }
}
