import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentinel/core/utils/auth_service.dart';
import 'package:sentinel/presentation/providers/auth_provider.dart';
import 'package:sentinel/presentation/providers/account_provider.dart';
import 'package:sentinel/presentation/widgets/dot_pattern_background.dart';
import 'package:sentinel/core/utils/logger_util.dart';

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
  AuthMethod _authMethod = AuthMethod.none;
  final _pinController = TextEditingController();
  String _errorMessage = '';
  bool _showPinAuth = false;

  @override
  void initState() {
    super.initState();

    // Preload accounts in the background before authentication completes
    // This avoids showing an empty list briefly when auth is successful
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(accountsProvider.notifier).loadAccounts();
    });

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

    // Check if authentication is required
    final authRequired = ref.read(authRequiredProvider);

    // Don't update state if not mounted (prevents state changes after dispose)
    if (!mounted) return;

    setState(() {
      _authMethod = authMethod;
    });

    // Skip authentication in these cases:
    // 1. Authentication is not required (app lock disabled or no auth method)
    if (!authRequired) {
      if (mounted) {
        setState(() {
          _isAuthenticated = true;
        });
      }
      return;
    }

    // 2. Not checking app lock (for screens that don't require auth)
    if (!widget.checkAppLock) {
      if (mounted) {
        setState(() {
          _isAuthenticated = true;
        });
      }
      return;
    }

    // If biometric auth is enabled in any form, try it immediately
    if ((_authMethod == AuthMethod.biometric ||
            _authMethod == AuthMethod.both) &&
        mounted) {
      LoggerUtil.debug('Auto-triggering biometric authentication during init');
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
    try {
      LoggerUtil.debug('Starting biometric authentication');
      final isAuthenticated = await AuthService.authenticateWithBiometrics();

      // Only update state if still mounted
      if (!mounted) return;

      setState(() {
        _isAuthenticated = isAuthenticated;
        if (!isAuthenticated) {
          _errorMessage = 'Biometric authentication failed or was canceled';
          LoggerUtil.warning(
            'Biometric auth failed or was canceled - keeping UI active for PIN fallback',
          );
          // We deliberately don't modify _authMethod here to keep the biometric UI
          // with the PIN fallback button visible
        } else {
          _errorMessage = '';
        }
      });
    } catch (e, stack) {
      LoggerUtil.error('Error during biometric authentication', e, stack);
      if (mounted) {
        setState(() {
          _errorMessage = 'Authentication error: ${e.toString()}';
          // Don't automatically switch to PIN - the user should be able to retry biometrics
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get current theme brightness and colors
    final brightness = Theme.of(context).brightness;
    final isDarkMode = brightness == Brightness.dark;
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ??
        (isDarkMode ? Colors.white : Colors.black);
    final subTextColor = isDarkMode ? Colors.white70 : Colors.black54;
    final primaryColor = Theme.of(context).primaryColor;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;

    // Watch the auth providers to react to changes
    final authMethod = ref.watch(authMethodProvider);

    // Also watch auth required status
    final authRequired = ref.watch(authRequiredProvider);

    // Update state if auth method changes
    if (authMethod != _authMethod) {
      setState(() {
        _authMethod = authMethod;

        // If auth method is none, automatically authenticate
        if (_authMethod == AuthMethod.none) {
          _isAuthenticated = true;
        }
      });
    }

    // Skip authentication if auth is not required
    if (!authRequired) {
      return widget.child;
    }

    // Skip authentication for non-app-lock screens
    if (!widget.checkAppLock) {
      return widget.child;
    }

    // If already authenticated, show the child
    if (_isAuthenticated) {
      // Show the child screen
      return widget.child;
    }

    // We'll check PIN status during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPinStatus();
    });

    // Otherwise, show the auth screen
    return Scaffold(
      body: Stack(
        children: [
          // Dot pattern background
          const DotPatternBackground(opacity: 0.03),

          // Solid background color instead of gradient
          Container(color: backgroundColor),

          // Main content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.security, size: 80, color: textColor),
                    const SizedBox(height: 24),
                    Text(
                      'Authentication Required',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please authenticate to access your accounts',
                      style: TextStyle(fontSize: 16, color: subTextColor),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // Build the appropriate auth UI based on current state
                    _buildAuthMethodUI(),

                    // Show error message if any
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
        ],
      ),
    );
  }

  /// Check PIN status to ensure we show the right UI options
  Future<void> _checkPinStatus() async {
    try {
      // Get values we need
      final hasPin = await AuthService.hasPin();
      final bioAvailable =
          ref.read(biometricAvailableProvider).valueOrNull ?? false;

      // Only update state if mounted to avoid setState after dispose
      if (!mounted) return;

      // If biometric auth is enabled/selected and PIN is available, show PIN option
      // We don't check biometric availability here so the PIN option always appears
      if (_authMethod == AuthMethod.biometric && hasPin && !_isAuthenticated) {
        // Find our widget in the tree
        final context = this.context;
        if (!context.mounted) return;

        // Get current theme brightness
        final brightness = Theme.of(context).brightness;
        final isDarkMode = brightness == Brightness.dark;
        final primaryColor = Theme.of(context).primaryColor;
        final textColor =
            Theme.of(context).textTheme.bodyLarge?.color ??
            (isDarkMode ? Colors.white : Colors.black);
        final actionColor =
            isDarkMode ? primaryColor : Theme.of(context).colorScheme.primary;

        // Find scaffold messenger to show PIN option
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        if (!scaffoldMessenger.mounted) return;

        // Show persistent button to switch to PIN
        scaffoldMessenger.clearSnackBars();
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              'Use PIN instead?',
              style: TextStyle(color: textColor),
            ),
            backgroundColor:
                isDarkMode ? Colors.grey.shade900 : Colors.grey.shade200,
            duration: const Duration(
              days: 1,
            ), // Effectively permanent until dismissed
            action: SnackBarAction(
              label: 'USE PIN',
              textColor: actionColor,
              onPressed: () {
                setState(() {
                  // Temporarily switch to PIN auth
                  _authMethod = AuthMethod.pin;
                });
                scaffoldMessenger.clearSnackBars();
              },
            ),
          ),
        );
      }

      // If showing PIN but biometric is configured as preferred method, offer biometric option
      if (_authMethod == AuthMethod.pin &&
          bioAvailable &&
          ref.read(authMethodProvider) == AuthMethod.biometric &&
          !_isAuthenticated) {
        // Update UI to show biometric option
        setState(() {});
      }
    } catch (e, stack) {
      LoggerUtil.error('Error checking PIN status', e, stack);
    }
  }

  /// Build the appropriate authentication UI based on current state
  Widget _buildAuthMethodUI() {
    LoggerUtil.debug('Building auth UI for method: $_authMethod');

    // When both methods are available, prefer biometric but show PIN option too
    if (_authMethod == AuthMethod.both) {
      return _buildBothAuthUI();
    }

    // Show PIN entry if PIN auth is enabled
    if (_authMethod == AuthMethod.pin) {
      return _buildPinAuthUI();
    }

    // Show biometric button if biometric auth is enabled
    // The actual authenticateWithBiometrics method will handle availability properly
    if (_authMethod == AuthMethod.biometric) {
      return _buildBiometricAuthUI();
    }

    // Default empty widget if no method matches
    return const SizedBox.shrink();
  }

  /// Build PIN authentication UI
  Widget _buildPinAuthUI() {
    // Read the current auth method and biometric availability directly when needed
    final currentAuthMethod = ref.read(authMethodProvider);
    final biometricAvailable =
        ref.read(biometricAvailableProvider).valueOrNull ?? false;

    // Get current theme brightness
    final brightness = Theme.of(context).brightness;
    final isDarkMode = brightness == Brightness.dark;

    // Get dynamic colors based on current theme
    final primaryColor = Theme.of(context).primaryColor;
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ??
        (isDarkMode ? Colors.white : Colors.black);
    final labelColor = isDarkMode ? Colors.white70 : Colors.black87;
    final borderColor = isDarkMode ? Colors.white54 : Colors.grey.shade400;
    final iconColor = isDarkMode ? Colors.white70 : Colors.black54;
    final buttonTextColor = Theme.of(context).colorScheme.onPrimary;

    return Column(
      children: [
        TextField(
          controller: _pinController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          obscureText: true,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Enter PIN',
            labelStyle: TextStyle(color: labelColor),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: primaryColor),
            ),
            prefixIcon: Icon(Icons.pin, color: iconColor),
            counterStyle: TextStyle(color: labelColor),
          ),
          style: TextStyle(color: textColor),
          onSubmitted: (_) => _authenticateWithPin(),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _authenticateWithPin,
          style: ElevatedButton.styleFrom(
            foregroundColor: buttonTextColor,
            backgroundColor: Theme.of(context).colorScheme.primary,
            elevation: 0, // No shadow
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text('UNLOCK'),
        ),

        // Show biometric option if available
        if (biometricAvailable &&
            (currentAuthMethod == AuthMethod.biometric ||
                currentAuthMethod == AuthMethod.both))
          TextButton.icon(
            onPressed: () {
              setState(() {
                // Switch back to biometric or both auth
                _authMethod = currentAuthMethod;
                _authenticateWithBiometrics();
              });
            },
            icon: Icon(Icons.fingerprint, color: labelColor),
            label: Text('Use Biometrics', style: TextStyle(color: labelColor)),
          ),
      ],
    );
  }

  /// Build biometric authentication UI
  Widget _buildBiometricAuthUI() {
    // Get current theme brightness
    final brightness = Theme.of(context).brightness;
    final isDarkMode = brightness == Brightness.dark;

    // Get dynamic colors based on current theme
    final primaryColor = Theme.of(context).primaryColor;
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ??
        (isDarkMode ? Colors.white : Colors.black);
    final labelColor = isDarkMode ? Colors.white70 : Colors.black87;
    final buttonTextColor = Theme.of(context).colorScheme.onPrimary;
    final borderColor = isDarkMode ? Colors.white54 : Colors.grey.shade400;

    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: () {
            // Clear error message when retrying
            setState(() {
              _errorMessage = '';
            });
            _authenticateWithBiometrics();
          },
          style: ElevatedButton.styleFrom(
            foregroundColor: buttonTextColor,
            backgroundColor: Theme.of(context).colorScheme.primary,
            elevation: 0, // No shadow
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          icon: const Icon(Icons.fingerprint),
          label: const Text('AUTHENTICATE WITH BIOMETRICS'),
        ),

        // Add PIN fallback button - only when PIN is actually configured
        FutureBuilder<bool>(
          future: AuthService.hasPin(),
          builder: (context, snapshot) {
            final hasPin = snapshot.data ?? false;

            if (hasPin) {
              return Padding(
                padding: const EdgeInsets.only(top: 24),
                child: OutlinedButton.icon(
                  onPressed: () {
                    LoggerUtil.debug('PIN fallback button pressed');
                    // First clear any existing snackbars
                    ScaffoldMessenger.of(context).clearSnackBars();

                    setState(() {
                      LoggerUtil.debug('Switching to PIN authentication mode');
                      _authMethod = AuthMethod.pin;
                      // Clear any existing error message
                      _errorMessage = '';
                    });
                  },
                  icon: Icon(Icons.pin, color: textColor),
                  label: Text(
                    'USE PIN INSTEAD',
                    style: TextStyle(color: textColor),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: borderColor),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              );
            } else {
              return const SizedBox.shrink(); // Don't show PIN option if no PIN is set
            }
          },
        ),

        // Show a retry button if authentication failed
        if (_errorMessage.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _errorMessage = '';
                });
                _authenticateWithBiometrics();
              },
              icon: Icon(Icons.refresh, color: labelColor),
              label: Text(
                'RETRY BIOMETRICS',
                style: TextStyle(color: labelColor),
              ),
            ),
          ),
      ],
    );
  }

  /// Build UI for when both auth methods are available
  Widget _buildBothAuthUI() {
    // Get current theme brightness
    final brightness = Theme.of(context).brightness;
    final isDarkMode = brightness == Brightness.dark;

    // Get dynamic colors based on current theme
    final primaryColor = Theme.of(context).primaryColor;
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ??
        (isDarkMode ? Colors.white : Colors.black);
    final labelColor = isDarkMode ? Colors.white70 : Colors.black87;
    final buttonTextColor = Theme.of(context).colorScheme.onPrimary;
    final borderColor = isDarkMode ? Colors.white54 : Colors.grey.shade400;
    final dividerColor = isDarkMode ? Colors.white24 : Colors.grey.shade300;

    // Automatically trigger biometrics immediately when this UI is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isAuthenticated && _errorMessage.isEmpty) {
        LoggerUtil.debug('Automatically triggering biometric authentication');
        _authenticateWithBiometrics();
      }
    });

    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: () {
            // Clear error message when retrying
            setState(() {
              _errorMessage = '';
            });
            _authenticateWithBiometrics();
          },
          style: ElevatedButton.styleFrom(
            foregroundColor: buttonTextColor,
            backgroundColor: Theme.of(context).colorScheme.primary,
            elevation: 0, // No shadow
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          icon: const Icon(Icons.fingerprint),
          label: const Text('AUTHENTICATE WITH BIOMETRICS'),
        ),

        // Only show PIN option if PIN is actually configured
        FutureBuilder<bool>(
          future: AuthService.hasPin(),
          builder: (context, snapshot) {
            final hasPin = snapshot.data ?? false;

            if (hasPin) {
              return Padding(
                padding: const EdgeInsets.only(top: 24),
                child: OutlinedButton.icon(
                  onPressed: () {
                    LoggerUtil.debug(
                      'Switching to PIN authentication from both mode',
                    );
                    setState(() {
                      // Temporarily use PIN auth
                      _showPinAuth = true;
                    });
                  },
                  icon: Icon(Icons.pin, color: textColor),
                  label: Text(
                    'USE PIN INSTEAD',
                    style: TextStyle(color: textColor),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: borderColor),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              );
            } else {
              return const SizedBox.shrink(); // Don't show PIN option if no PIN is set
            }
          },
        ),

        // Show a retry button if authentication failed
        if (_errorMessage.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _errorMessage = '';
                });
                _authenticateWithBiometrics();
              },
              icon: Icon(Icons.refresh, color: labelColor),
              label: Text(
                'RETRY BIOMETRICS',
                style: TextStyle(color: labelColor),
              ),
            ),
          ),

        // Show PIN UI when requested
        if (_showPinAuth) ...[
          const SizedBox(height: 32),
          Divider(color: dividerColor),
          const SizedBox(height: 16),
          _buildPinAuthUI(),
        ],
      ],
    );
  }
}
