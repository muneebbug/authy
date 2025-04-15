import 'package:flutter/material.dart';

/// Observer for handling app lifecycle changes
class AppLifecycleObserver {
  final VoidCallback? onResume;
  final VoidCallback? onPause;
  final VoidCallback? onDetach;
  final VoidCallback? onInactive;
  final VoidCallback? onHidden;

  AppLifecycleObserver({
    this.onResume,
    this.onPause,
    this.onDetach,
    this.onInactive,
    this.onHidden,
  });

  late WidgetsBindingObserver _observer;

  void initialize() {
    _observer = _AppLifecycleObserverImpl(
      onResume: onResume,
      onPause: onPause,
      onDetach: onDetach,
      onInactive: onInactive,
      onHidden: onHidden,
    );
    WidgetsBinding.instance.addObserver(_observer);
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(_observer);
  }
}

class _AppLifecycleObserverImpl with WidgetsBindingObserver {
  final VoidCallback? onResume;
  final VoidCallback? onPause;
  final VoidCallback? onDetach;
  final VoidCallback? onInactive;
  final VoidCallback? onHidden;

  _AppLifecycleObserverImpl({
    this.onResume,
    this.onPause,
    this.onDetach,
    this.onInactive,
    this.onHidden,
  });

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        onResume?.call();
        break;
      case AppLifecycleState.paused:
        onPause?.call();
        break;
      case AppLifecycleState.detached:
        onDetach?.call();
        break;
      case AppLifecycleState.inactive:
        onInactive?.call();
        break;
      case AppLifecycleState.hidden:
        onHidden?.call();
        break;
    }
  }
}
