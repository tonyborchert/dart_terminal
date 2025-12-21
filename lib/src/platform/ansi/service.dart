// Dart imports:
import 'dart:async' as async;
import 'dart:io' as io;

// Project imports:
import 'package:characters/characters.dart';
import 'package:dart_terminal/core.dart';
import 'package:dart_terminal/src/platform/ansi/strings/sanitize.dart';
import '../shared/native_terminal_image.dart';
import '../shared/signals.dart';
import '../shared/size_tracker.dart';
import '../shared/terminal_capabilities.dart';
import 'controller.dart';
import 'input_processor.dart';
import 'logger.dart';
import 'viewport.dart';

class AnsiTerminalService extends TerminalService {
  final TerminalCapabilitiesDetector _capabilitiesDetector;
  final TerminalSizeTracker _sizeTracker;
  final InputProcessor _inputProcessor = InputProcessor();
  final AnsiTerminalController _controller = AnsiTerminalController();

  final List<async.StreamSubscription<Object>> _subscriptions = [];
  late final AnsiTerminalViewport _viewport;
  TerminalViewport get viewport => _viewport;
  late final AnsiTerminalLogger _logger;
  TerminalLogger get logger => _logger;

  /// Creates a new factory with specific capability detection and size tracking.
  AnsiTerminalService({
    required TerminalCapabilitiesDetector capabilitiesDetector,
    required TerminalSizeTracker sizeTracker,
  }) : _capabilitiesDetector = capabilitiesDetector,
       _sizeTracker = sizeTracker {
    _viewport = AnsiTerminalViewport(_controller, _sizeTracker);
    _logger = AnsiTerminalLogger(_sizeTracker);
  }

  /// Creates a factory with automatic configuration
  /// corresponding to the current platform.
  ///
  /// This factory method provides sensible defaults for most use cases:
  /// - Automatically detects terminal capabilities
  /// - Sets up appropriate size tracking for the
  factory AnsiTerminalService.agnostic({
    Duration? terminalSizePollingInterval,
  }) {
    final capabilitiesDetector = TerminalCapabilitiesDetector.agnostic();
    final sizeTracker = TerminalSizeTracker.agnostic(
      pollingInterval:
          terminalSizePollingInterval ?? Duration(milliseconds: 50),
    );
    return AnsiTerminalService(
      capabilitiesDetector: capabilitiesDetector,
      sizeTracker: sizeTracker,
    );
  }

  @override
  Future<void> attach() async {
    // TODO: detect if is first attachment
    await _capabilitiesDetector.detect();
    _controller
      ..changeFocusTrackingMode(enable: true)
      ..setInputMode(enableRaw: true)
      ..changeBracketedPasteMode(enable: true);
    _inputProcessor..startListening(io.stdin);
    _inputProcessor.pasteListener = (data) => listener?.keyboardInput(
      PasteTextInput(
        rawStringRepresentation: data,
        sanitizedStringRepresentation: sanitize(data),
        fromBracketedPaste: true,
      ),
    );
    _inputProcessor.charListener = (data) {
      listener?.keyboardInput(UnicodeChar(data.characters));
    };
    _inputProcessor.mouseListener = (event) => listener?.mouseEvent(event);
    _inputProcessor.unhandledListener = (data) =>
        listener?.rawInput(RawTerminalInput(null, data), false);
    _inputProcessor.handledStringListener = (data) =>
        listener?.rawInput(RawTerminalInput(null, data), true);
    _inputProcessor.keyStrokeListener = (keyStroke) =>
        listener?.keyboardInput(keyStroke);
    _inputProcessor.focusListener = (hasFocus) =>
        listener?.focusChange(hasFocus);

    for (final signal in AllowedSignal.values) {
      _subscriptions.add(
        signal.processSignal().watch().listen((_) {
          listener?.signal(signal);
        }),
      );
    }
    _sizeTracker
      ..startTracking()
      ..listener = _onResizeEvent;
    await super.attach();
  }

  @override
  Future<void> detach() async {
    final viewPortWasActive = _viewport.isActive;
    super.detach();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    _inputProcessor.stopListening();
    _sizeTracker.stopTracking();
    if (viewPortWasActive) {
      _viewport.deactivate();
    }
    _controller
      ..setInputMode(enableRaw: false)
      ..changeFocusTrackingMode(enable: false)
      ..changeBracketedPasteMode(enable: true);
  }

  @override
  void loggerMode() {
    if (_logger.isActive) return;
    super.loggerMode();
    if (_viewport.isActive) _viewport.deactivate();
  }

  @override
  void viewPortMode() {
    if (_viewport.isActive) return;
    super.viewPortMode();
    _viewport.activate();
  }

  void _onResizeEvent() {
    if (_viewport.isActive) _viewport.resize();
    listener?.screenResize(_sizeTracker.currentSize);
  }

  @override
  NativeTerminalImage createImage({
    required Size size,
    String? filePath,
    Color? backgroundColor,
  }) {
    if (filePath != null) {
      return NativeTerminalImage.fromPath(
        size: size,
        path: filePath,
        backgroundColor: backgroundColor,
      );
    }
    return NativeTerminalImage.filled(size, backgroundColor);
  }

  @override
  CapabilitySupport checkSupport(Capability capability) {
    if (_capabilitiesDetector.supportedCaps.contains(capability)) {
      return CapabilitySupport.supported;
    }
    if (_capabilitiesDetector.assumedCaps.contains(capability)) {
      return CapabilitySupport.assumed;
    }
    if (_capabilitiesDetector.unsupportedCaps.contains(capability)) {
      return CapabilitySupport.unsupported;
    }
    return CapabilitySupport.unknown;
  }

  @override
  void bell() => _controller.bell();

  @override
  void setTerminalTitle(String title) => _controller.changeTerminalTitle(title);

  @override
  void setTerminalIcon(String icon) => _controller.changeTerminalIcon(icon);

  @override
  void trySetTerminalSize(Size size) =>
      _controller.changeSize(size.width, size.height);

  @override
  String sanitizeInputString(String input) => sanitize(input);
}
