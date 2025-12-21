// Project imports:
import 'primitives.dart';
import 'geometry.dart';
import 'graphics.dart';
import 'style.dart';

/// Service for creating and managing terminal windows and associated objects.
///
/// Provides an abstract interface for terminal operations, allowing for different
/// implementations depending on the underlying platform or terminal capabilities.
abstract class TerminalService {
  /// Initializes the terminal service.
  bool _isAttached = false;

  Future<void> attach() async {
    assert(!_isAttached, "TerminalWindow has already been attached.");
    _isAttached = true;
    logger._isActive = true;
  }

  Future<void> detach() async {
    assert(_isAttached, "TerminalWindow has not been attached.");
    _isAttached = false;
    logger._isActive = false;
    viewport._isActive = false;
  }

  TerminalListener? listener;

  TerminalLogger get logger;
  TerminalViewport get viewport;

  void loggerMode() {
    logger._isActive = true;
    viewport._isActive = false;
  }

  void viewPortMode() {
    logger._isActive = false;
    viewport._isActive = true;
  }

  TerminalImage createImage({
    required Size size,
    String? filePath,
    Color? backgroundColor,
  });

  /// Checks if a specific capability is supported by the terminal.
  CapabilitySupport checkSupport(Capability capability);

  /// Tries to set the terminal size, adjusting if necessary.
  void trySetTerminalSize(Size size);

  /// Sets the terminal window title.
  void setTerminalTitle(String title);

  /// Sets the terminal window title.
  ///
  /// (In principle is also a title but showed differently by
  /// some terminal emulators).
  void setTerminalIcon(String icon);

  /// Triggers the terminal bell (audible or visible alert).
  void bell();

  /// Sanitizes an input string to ensure it is safe for terminal display.
  ///
  /// Should be used to prevent injection of control characters by raw user input.
  String sanitizeInputString(String input);
}

/// Represents the default terminal where one can print log messages
/// and set a status log.
abstract class TerminalLogger {
  bool get isActive => _isActive;
  bool _isActive = false;

  Size get size;

  /// Logs a message to the terminal.
  ///
  /// If the message does not end with a newline,
  /// the next message will continue on the same line.
  void log(TextSpan span);

  /// The status log is rendered directly under the last log line
  /// and often reflects what the user is currently doing,
  /// for example showing progress or an input of the user.
  ///
  /// It is updated frequently (completely replacing the previous status log).
  /// Often it makes sense to update the status log after a size change
  /// to ensure it fits the new width.
  ///
  /// Of the [cursorState], the [CursorState.position]
  /// attribute is relative from the beginning of the status log.
  /// Further, the [CursorState.position]
  /// should be bounded to the current width of [size].
  void setStatusLog(TextSpan span, CursorState? cursorState);

  /// Clears the complete terminal buffer,
  /// including output from previous commands.
  void clear();
}

/// Abstract class for terminal windows.
///
/// Represents a window in the terminal where content can be displayed.
/// Supports features like cursor management, screen updating, and event handling.
abstract class TerminalViewport implements TerminalCanvas {
  bool get isActive => _isActive;
  bool _isActive = false;

  CursorState? get cursor;
  set cursor(CursorState? state);

  /// Draws the background of the terminal window.
  void drawColor({Color color, bool optimizeByClear = true});

  @override
  void drawBorderBox({
    required Rect rect,
    required BorderCharSet style,
    Color color = const Color.normal(),
    BorderDrawIdentifier? drawId,
  }) {
    assert(rect.height > 1 && rect.width > 1, "Rect needs to be at least 2x2.");
  }

  @override
  void drawBorderLine({
    required Position from,
    required Position to,
    required BorderCharSet style,
    Color color = const Color.normal(),
    BorderDrawIdentifier? drawId,
  }) {
    assert(
      from.x == to.x || from.y == to.y,
      "Points need to be either horizontally or vertically aligned.",
    );
    assert(from != to, "Points need to be different.");
  }

  void drawImage({
    required covariant TerminalImage image,
    required Position position,
  });

  /// Updates the terminal screen with any pending changes.
  void updateScreen();
}

/// Interface for handling terminal events.
///
/// Implement this interface to receive events from the terminal such as
/// input, screen resizes, and signal interruptions.
abstract interface class TerminalListener {
  /// Called when the terminal screen is resized.
  void screenResize(Size size);

  /// Called when there is (non mouse) input from the user that could be interpreted.
  void keyboardInput(KeyboardInput input);

  /// Called when there is any input.
  void rawInput(RawTerminalInput input, bool wasFullyProcessed);

  /// Called when the terminal receives a system signal.
  @deprecated
  void signal(AllowedSignal signal);

  /// Called for mouse events like clicks and movement.
  /// (only available in viewport mode)
  void mouseEvent(MouseEvent event) {}

  /// Called when the terminal gains or loses focus.
  void focusChange(bool isFocused);

  /// Creates a delegate that forwards events to the provided handlers.
  factory TerminalListener({
    void Function(Size) onScreenResize,
    void Function(KeyboardInput) onKeyboardInput,
    void Function(RawTerminalInput input, bool wasFullyProcessed) onRawInput,
    void Function(bool) onFocusChange,
    void Function(String) onInput,
    void Function(MouseEvent) onMouseEvent,
    void Function(AllowedSignal) onSignal,
  }) = _LambdaTerminalListener;
}

class _LambdaTerminalListener implements TerminalListener {
  void Function(KeyboardInput) onKeyboardInput;
  // ignore: avoid_positional_boolean_parameters
  void Function(RawTerminalInput input, bool wasFullyProcessed) onRawInput;
  void Function(bool) onFocusChange;
  void Function(String) onInput;
  void Function(MouseEvent) onMouseEvent;
  void Function(Size) onScreenResize;
  void Function(AllowedSignal) onSignal;

  static void _(_, [_]) {}

  _LambdaTerminalListener({
    this.onKeyboardInput = _,
    // ignore: avoid_positional_boolean_parameters
    this.onFocusChange = _,
    this.onRawInput = _,
    this.onInput = _,
    this.onMouseEvent = _,
    this.onScreenResize = _,
    this.onSignal = _,
  });

  @override
  void keyboardInput(KeyboardInput input) => onKeyboardInput(input);

  @override
  void rawInput(RawTerminalInput input, bool wasFullyProcessed) =>
      onRawInput(input, wasFullyProcessed);

  @override
  void focusChange(bool isFocused) => onFocusChange(isFocused);

  @override
  void mouseEvent(MouseEvent event) => onMouseEvent(event);

  @override
  void screenResize(Size size) => onScreenResize(size);

  @override
  void signal(AllowedSignal signal) => onSignal(signal);
}

class DefaultTerminalListener implements TerminalListener {
  @override
  void focusChange(bool isFocused) {}

  @override
  void keyboardInput(KeyboardInput controlCharacter) {}

  @override
  void mouseEvent(MouseEvent event) {}

  @override
  void rawInput(RawTerminalInput input, bool wasFullyProcessed) {}

  @override
  void screenResize(Size size) {}

  @override
  void signal(AllowedSignal signal) {}
}
