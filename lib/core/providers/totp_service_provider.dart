import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentinel/core/utils/totp_service.dart';

/// Provider for the TOTP service
final totpServiceProvider = FutureProvider<TOTPService>((ref) async {
  // Initialize time synchronization
  await TOTPService.initializeTimeSync();

  // Return the TOTPService class instance (it's a static class)
  return TOTPService();
});
