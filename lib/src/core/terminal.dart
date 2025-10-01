// Project imports:
import 'primitives.dart';
import 'geometry.dart';
import 'graphics.dart';
import 'style.dart';
import 'util.dart';

/// Service for creating and managing terminal windows and associated objects.
///
/// Provides an abstract interface for terminal operations, allowing for different
/// implementations depending on the underlying platform or terminal capabilities.
abstract class TerminalService {
  /// Initializes the terminal service.
  bool _isAttached = false;

  Future<void> attach() async {
    assert(_isAttached, "TerminalWindow has already been attached.");
    _isAttached = true;
    logger._isActive = true;
  }

  Future<void> detach() async {
    assert(!_isAttached, "TerminalWindow has not been attached.");
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
}

abstract class TerminalLogger {
  bool get isActive => _isActive;
  bool _isActive = false;

  int get width;

  void deleteLastLine(int count);

  void log(
    String text, {
    ForegroundStyle foregroundStyle,
    Color backgroundColor,
  });
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

/// Represents the state of the text cursor.
///
/// Includes the cursor's position and whether it is currently blinking.
final class CursorState {
  final Position position;
  final CursorType type;
  final bool blinking;

  CursorState({
    required this.position,
    this.type = CursorType.block,
    this.blinking = true,
  });

  @override
  bool operator ==(Object other) =>
      other is CursorState &&
      position == other.position &&
      blinking == other.blinking;

  @override
  int get hashCode => Object.hash(position.hashCode, blinking);
}

/// Base class for mouse events in the terminal.
///
/// Provides common properties for all mouse-related events including
/// modifier key states and cursor position.
sealed class MouseEvent {
  /// Whether the shift key was pressed during the event
  final bool shiftKeyPressed;

  /// Whether the meta (command/windows) key was pressed
  final bool metaKeyPressed;

  /// Whether the control key was pressed
  final bool ctrlKeyPressed;

  /// The position of the mouse cursor when the event occurred
  final Position position;

  const MouseEvent(
    this.shiftKeyPressed,
    this.metaKeyPressed,
    this.ctrlKeyPressed,
    this.position,
  );
}

/// Represents a mouse button press or release event.
///
/// Includes information about which button was involved and the type of press.
final class MousePressEvent extends MouseEvent {
  /// The mouse button that triggered the event
  final MouseButton button;

  /// The type of press event (click, double-click, etc)
  final MouseButtonState buttonState;

  const MousePressEvent(
    super.shiftKeyPressed,
    super.metaKeyPressed,
    super.ctrlKeyPressed,
    super.position,
    this.button,
    this.buttonState,
  );
}

/// Represents mouse movement without button presses.
///
/// Used for tracking mouse position during hover operations.
final class MouseHoverEvent extends MouseEvent {
  const MouseHoverEvent(
    super.shiftKeyPressed,
    super.metaKeyPressed,
    super.ctrlKeyPressed,
    super.position,
  );
}

/// Represents mouse wheel scrolling.
///
/// Contains information about the scroll amount in both x and y directions.
final class MouseScrollEvent extends MouseEvent {
  /// The amount of scrolling in the x direction
  final int xScroll;

  /// The amount of scrolling in the y direction
  final int yScroll;

  const MouseScrollEvent(
    super.shiftKeyPressed,
    super.metaKeyPressed,
    super.ctrlKeyPressed,
    super.position,
    this.xScroll,
    this.yScroll,
  );
}

/// Interface for handling terminal events.
///
/// Implement this interface to receive events from the terminal such as
/// input, screen resizes, and signal interruptions.
abstract interface class TerminalListener {
  /// Called when the terminal screen is resized.
  void screenResize(Size size);

  /// Called when there is input from the user.
  void input(String s);

  /// Called for control characters like Ctrl+C.
  void controlCharacter(ControlCharacter controlCharacter);

  /// Called when the terminal receives a system signal.
  void signal(AllowedSignal signal);

  /// Called for mouse events like clicks and movement.
  /// (only available in viewport mode)
  void mouseEvent(MouseEvent event);

  /// Called when the terminal gains or loses focus.
  void focusChange(bool isFocused);

  /// Creates a delegate that forwards events to the provided handlers.
  factory TerminalListener({
    void Function(ControlCharacter) onControlCharacter,
    void Function(bool) onFocusChange,
    void Function(String) onInput,
    void Function(MouseEvent) onMouseEvent,
    void Function(Size) onScreenResize,
    void Function(AllowedSignal) onSignal,
  }) = LambdaTerminalListener;
}
