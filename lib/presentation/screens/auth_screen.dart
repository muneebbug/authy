import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:authy/core/utils/auth_service.dart';
import 'package:authy/presentation/providers/auth_provider.dart';
import 'package:authy/presentation/widgets/dot_pattern_background.dart';

/// Screen for authenticating the user with PIN or biometric
class AuthScreen extends ConsumerStatefulWidget {
  final Widget child;
  final bool checkAppLock;

  const AuthScreen({Key? key, required this.child, this.checkAppLock = true})
    : super(key: key);

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
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
    // Don't proceed if not mounted (prevents state changes after dispose)
    if (!mounted) return;

    // Get auth method from provider
    final authMethod = ref.read(authMethodProvider);

    // Check biometric availability
    final biometricAvailable = await ref.read(
      biometricAvailableProvider.future,
    );

    // Check app lock setting
    final appLockEnabled = ref.read(appLockProvider);

    // Don't update state if not mounted (prevents state changes after dispose)
    if (!mounted) return;

    setState(() {
      _authMethod = authMethod;
      _isBiometricAvailable = biometricAvailable;
    });

    // Skip authentication if:
    // 1. No auth method set
    if (_authMethod == AuthMethod.none) {
      if (mounted) {
        setState(() {
          _isAuthenticated = true;
        });
      }
      return;
    }

    // For app lock behavior - this indicates we're checking after app was in background
    if (widget.checkAppLock) {
      // Only skip auth if app lock is explicitly disabled
      if (!appLockEnabled) {
        if (mounted) {
          setState(() {
            _isAuthenticated = true;
          });
        }
        return;
      }
    } else {
      // Not checking app lock, skip authentication for non-lock screens
      if (mounted) {
        setState(() {
          _isAuthenticated = true;
        });
      }
      return;
    }

    // If biometric auth is enabled, try it immediately
    if (_authMethod == AuthMethod.biometric &&
        _isBiometricAvailable &&
        mounted) {
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
    // Watch the auth providers to react to changes
    final authMethod = ref.watch(authMethodProvider);
    final biometricAvailable =
        ref.watch(biometricAvailableProvider).valueOrNull ?? false;

    // Also watch app lock status
    final appLockEnabled = ref.watch(appLockProvider);

    // Update state if auth method changes
    if (authMethod != _authMethod ||
        biometricAvailable != _isBiometricAvailable) {
      setState(() {
        _authMethod = authMethod;
        _isBiometricAvailable = biometricAvailable;
      });
    }

    // If already authenticated, show the child
    if (_isAuthenticated) {
      return widget.child;
    }

    // Otherwise, show the auth screen
    return Scaffold(
      body: Stack(
        children: [
          // Dot pattern background
          const DotPatternBackground(opacity: 0.03),
          // Gradient container
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
        ],
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
