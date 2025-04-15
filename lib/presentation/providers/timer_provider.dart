import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentinel/presentation/providers/account_provider.dart';

/// A provider that updates the currentTimestampProvider every second
final timerProvider = Provider<void>((ref) {
  // Don't update the timestamp immediately - this causes provider initialization errors
  // Instead, schedule the first update to happen after initialization
  Future.microtask(() {
    ref.read(currentTimestampProvider.notifier).state =
        DateTime.now().millisecondsSinceEpoch ~/ 1000;
  });

  // Set up a timer to update the timestamp every second
  final timer = Timer.periodic(const Duration(seconds: 1), (_) {
    ref.read(currentTimestampProvider.notifier).state =
        DateTime.now().millisecondsSinceEpoch ~/ 1000;
  });

  // Clean up the timer when this provider is disposed
  ref.onDispose(() {
    timer.cancel();
  });

  return;
});
