import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:authy/domain/entities/account.dart';
import 'package:authy/presentation/providers/account_provider.dart';
import 'package:authy/core/utils/totp_service.dart';

/// Widget to display a 2FA account in the list
class AccountItem extends ConsumerStatefulWidget {
  /// The account to display
  final Account account;

  /// Callback when the account is tapped
  final VoidCallback? onTap;

  /// Constructor
  const AccountItem({Key? key, required this.account, this.onTap})
    : super(key: key);

  @override
  ConsumerState<AccountItem> createState() => _AccountItemState();
}

class _AccountItemState extends ConsumerState<AccountItem> {
  Timer? _refreshTimer;
  int _remainingSeconds = 30; // Default to period
  String? _currentCode;
  bool _isLoading = true;
  int _lastPeriod = 0;

  @override
  void initState() {
    super.initState();
    _initializeCode();
    _startRefreshTimer();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  /// Initialize the code and timer values
  Future<void> _initializeCode() async {
    // Get initial values
    _calculateRemainingSeconds();
    await _loadCode(force: true);
  }

  /// Start a timer to refresh the code and timer every second
  void _startRefreshTimer() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      // Update remaining seconds
      _calculateRemainingSeconds();

      // Check if we should reload the code (if period changed)
      final currentPeriod =
          DateTime.now().millisecondsSinceEpoch ~/
          1000 ~/
          widget.account.period;
      if (currentPeriod != _lastPeriod) {
        _lastPeriod = currentPeriod;
        _loadCode(force: true);
      }
    });
  }

  /// Calculate the remaining seconds directly
  void _calculateRemainingSeconds() {
    if (!mounted) return;

    final seconds = TOTPService.getRemainingSeconds(widget.account);
    setState(() {
      _remainingSeconds = seconds;
    });
  }

  /// Load the current TOTP code
  Future<void> _loadCode({bool force = false}) async {
    if (!mounted) return;

    // Don't show loading indicator if we already have a code, unless forced
    if (!force && _currentCode != null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Generate the code directly
      final code = await TOTPService.generateCode(widget.account);

      if (mounted) {
        setState(() {
          _currentCode = code;
          _isLoading = false;
        });

        // Update the last used timestamp
        final updatedAccount = widget.account.copyWith(
          lastUsedAt: DateTime.now(),
        );
        ref.read(accountsProvider.notifier).updateAccount(updatedAccount);
      }
    } catch (e) {
      print("Error loading code: $e");
      if (mounted) {
        setState(() {
          _currentCode = null;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Account icon or initials
                  _buildAccountIcon(),
                  const SizedBox(width: 12),

                  // Account details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.account.issuer,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.account.accountName,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Time indicator
                  _buildTimeIndicator(),
                ],
              ),

              const SizedBox(height: 16),

              // TOTP code
              Center(
                child:
                    _isLoading
                        ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : _buildTOTPCode(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build the account icon or initials
  Widget _buildAccountIcon() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Color(widget.account.colorCode),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          widget.account.issuer.isEmpty
              ? '?'
              : widget.account.issuer[0].toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  /// Build time remaining indicator
  Widget _buildTimeIndicator() {
    final progress = _remainingSeconds / widget.account.period;

    return SizedBox(
      width: 30,
      height: 30,
      child: Stack(
        children: [
          CircularProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[300],
            strokeWidth: 3,
            color: progress < 0.25 ? Colors.red : null,
          ),
          Center(
            child: Text(
              '$_remainingSeconds',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  /// Build the TOTP code with proper spacing
  Widget _buildTOTPCode() {
    if (_currentCode == null) {
      return const Text(
        'Error generating code',
        style: TextStyle(color: Colors.red),
      );
    }

    // Format code with spaces for better readability
    String formattedCode = '';
    for (int i = 0; i < _currentCode!.length; i++) {
      formattedCode += _currentCode![i];
      if (i % 3 == 2 && i < _currentCode!.length - 1) {
        formattedCode += ' ';
      }
    }

    return Text(
      formattedCode,
      style: const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        letterSpacing: 2,
      ),
    );
  }
}
