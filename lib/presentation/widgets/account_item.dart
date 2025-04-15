import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sentinel/domain/entities/account.dart';
import 'package:sentinel/presentation/providers/account_provider.dart';
import 'package:sentinel/core/utils/totp_service.dart';

/// Widget to display a 2FA account in the list with Nothing OS style
class AccountItem extends ConsumerStatefulWidget {
  /// The account to display
  final Account account;

  /// Callback when the account is tapped
  final VoidCallback? onTap;

  /// Callback when the account is long pressed
  final VoidCallback? onLongPress;

  /// Constructor
  const AccountItem({
    Key? key,
    required this.account,
    this.onTap,
    this.onLongPress,
  }) : super(key: key);

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
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.primary;

    return Card(
      child: InkWell(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Account avatar
                  _buildAccountAvatar(),
                  const SizedBox(width: 12),

                  // Account details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.account.issuer,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          widget.account.accountName,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[400],
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // TOTP code and timer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // TOTP code
                  _isLoading
                      ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 1.5),
                      )
                      : _buildNothingStyleCode(),

                  // Time indicator
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Stack(
                      children: [
                        CircularProgressIndicator(
                          value: _remainingSeconds / widget.account.period,
                          backgroundColor: Colors.grey.shade800,
                          strokeWidth: 2,
                          color: accentColor,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build the account avatar in Nothing-style
  Widget _buildAccountAvatar() {
    final Color dotColor;

    // Select dot color based on issuer name (first letter) for variety
    switch (widget.account.issuer.toLowerCase().isEmpty
        ? 'x'
        : widget.account.issuer.toLowerCase()[0]) {
      case 'a':
      case 'b':
      case 'c':
        dotColor = Colors.blue;
        break;
      case 'd':
      case 'e':
      case 'f':
        dotColor = Colors.pink;
        break;
      case 'g':
      case 'h':
      case 'i':
        dotColor = Colors.amber;
        break;
      case 'j':
      case 'k':
      case 'l':
        dotColor = Colors.green;
        break;
      case 'm':
      case 'n':
      case 'o':
        dotColor = Colors.purple;
        break;
      case 'p':
      case 'q':
      case 'r':
        dotColor = Colors.red;
        break;
      case 's':
      case 't':
      case 'u':
        dotColor = Colors.teal;
        break;
      default:
        dotColor = Colors.grey;
    }

    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: Colors.black,
        shape: BoxShape.circle,
        border: Border.all(color: dotColor, width: 1.0),
      ),
      child: Center(
        child: Text(
          widget.account.issuer.isEmpty
              ? '?'
              : widget.account.issuer[0].toUpperCase(),
          style: TextStyle(
            color: dotColor,
            fontSize: 18,
            fontWeight: FontWeight.normal,
          ),
        ),
      ),
    );
  }

  /// Build the Nothing OS style TOTP code display with dot-matrix numbers
  Widget _buildNothingStyleCode() {
    if (_currentCode == null) {
      return Text(
        '------',
        style: GoogleFonts.spaceMono(
          fontSize: 24,
          letterSpacing: 3,
          textStyle: Theme.of(context).textTheme.titleLarge,
        ),
      );
    }

    final code = _currentCode!;

    // Instead of using RichText, display each digit separately with spacing
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < code.length; i++) ...[
          Text(
            code[i],
            style: GoogleFonts.spaceMono(
              fontSize: 24,
              fontWeight: FontWeight.normal,
              letterSpacing: 3,
              textStyle: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          // Add space between characters, but not after the last one
          if (i < code.length - 1) const SizedBox(width: 12),
        ],
      ],
    );
  }
}
