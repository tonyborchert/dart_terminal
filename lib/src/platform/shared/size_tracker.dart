// Dart imports:
import 'dart:async' as async;
import 'dart:io' as io;

// Project imports:
import 'package:dart_terminal/core.dart';

/// System for tracking and responding to terminal window size changes.
///
/// This module provides platform-specific implementations for monitoring
/// terminal dimensions, enabling responsive UI updates when the terminal
/// is resized.
abstract class TerminalSizeTracker {
  /// Current dimensions of the terminal window
  Size get currentSize;

  /// Callback triggered when terminal size changes
  void Function()? listener;

  /// The actual determiner of the size.
  TerminalSizeDeterminer determiner;

  /// Begins monitoring terminal size changes
  void startTracking();

  /// Stops monitoring terminal size changes
  void stopTracking();

  TerminalSizeTracker({required this.determiner});

  /// Creates a platform-appropriate size tracker.
  ///
  /// Returns either a polling-based tracker (Windows) or a signal-based
  /// tracker (POSIX systems) depending on the platform.
  ///
  /// [pollingInterval] specifies how often to check for size changes
  /// on platforms that require polling.
  factory TerminalSizeTracker.agnostic({required Duration pollingInterval}) {
    final determiner = TerminalSizeDeterminer.agnostic();
    return io.Platform.isWindows
        ? PollingTerminalSizeTracker(determiner: determiner)
        : PosixTerminalSizeTracker(determiner: determiner);
  }
}

abstract interface class TerminalSizeDeterminer {
  Size determine();

  factory TerminalSizeDeterminer.agnostic() => io.stdout.hasTerminal
      ? NativeTerminalSizeDeterminer()
      : EnvironmentTerminalSizeDeterminer();
}

/// uses [io.stdout.terminalColumns]
class NativeTerminalSizeDeterminer implements TerminalSizeDeterminer {
  Size determine() => Size(io.stdout.terminalColumns, io.stdout.terminalLines);
}

/// Tracks the size using the environment variables $COLUMNS and $LINES
class EnvironmentTerminalSizeDeterminer implements TerminalSizeDeterminer {
  Size determine() {
    final columns = int.tryParse(io.Platform.environment["COLUMNS"] ?? "") ?? 0;
    final rows = int.tryParse(io.Platform.environment["LINES"] ?? "") ?? 0;
    return Size(columns, rows);
  }
}

/// POSIX-specific implementation of terminal size tracking.
/// Uses [io.stdout.terminalColumns] which is not always supported.
///
/// Uses the SIGWINCH signal to detect terminal window resizes on
/// Unix-like operating systems (Linux, macOS, etc).
class PosixTerminalSizeTracker extends TerminalSizeTracker {
  /// Cached terminal dimensions
  late Size _currentSize;

  @override
  Size get currentSize => _currentSize;

  /// Subscription to the SIGWINCH signal
  async.StreamSubscription<dynamic>? _sigwinchSub;

  PosixTerminalSizeTracker({required super.determiner});

  @override
  void startTracking() {
    // Initialize with current terminal size
    _currentSize = determiner.determine();

    // Ensure we're on a supported platform
    if (!io.Platform.isLinux &&
        !io.Platform.isMacOS &&
        io.Platform.operatingSystem.toLowerCase() != 'solaris') {
      throw UnsupportedError('POSIX tracking only supported on Unix-like OS');
    }

    // Set up SIGWINCH handler for terminal resize events
    _sigwinchSub = io.ProcessSignal.sigwinch.watch().listen((_) {
      _currentSize = determiner.determine();
      listener?.call();
    });
  }

  @override
  void stopTracking() {
    _sigwinchSub?.cancel();
  }
}

// ------------------------------
// Polling implementation
// ------------------------------
/// Windows-specific implementation of terminal size tracking.
class PollingTerminalSizeTracker extends TerminalSizeTracker {
  final Duration _interval;
  async.Timer? _timer;
  late Size _currentSize;

  /// Creates a polling-based terminal size tracker.
  PollingTerminalSizeTracker({
    required super.determiner,
    Duration interval = const Duration(milliseconds: 200),
  }) : _interval = interval;

  @override
  Size get currentSize => _currentSize;

  @override
  void startTracking() {
    _currentSize = determiner.determine();
    _timer ??= async.Timer.periodic(_interval, (_) {
      final newSize = determiner.determine();
      if (newSize == _currentSize) {
        _currentSize = newSize;
        listener?.call();
      }
    });
  }

  @override
  void stopTracking() {
    _timer?.cancel();
    _timer = null;
  }
}
