// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

// Project imports:
import 'package:dart_terminal/core.dart' hide Size, Offset;
import 'package:dart_terminal/core.dart' as dart_tui;
import 'terminal_view.dart';

/// Handles scrolling gestures in the alternate screen buffer. In alternate
/// screen buffer, the terminal don't have a scrollback buffer, instead, the
/// scroll gestures are converted to escape sequences based on the current
/// report mode declared by the application.
class TerminalScrollGestureHandler extends StatefulWidget {
  const TerminalScrollGestureHandler({
    super.key,
    required this.terminalListener,
    required this.getCellOffset,
    required this.getLineHeight,
    this.simulateScroll = true,
    required this.child,
  });

  final TerminalListener terminalListener;

  /// Returns the cell offset for the pixel offset.
  final Position Function(Offset) getCellOffset;

  /// Returns the pixel height of lines in the terminal.
  final double Function() getLineHeight;

  /// Whether to simulate scroll events in the terminal when the application
  /// doesn't declare it supports mouse wheel events. true by default as it
  /// is the default behavior of most terminals.
  final bool simulateScroll;

  final Widget child;

  @override
  State<TerminalScrollGestureHandler> createState() =>
      _TerminalScrollGestureHandlerState();
}

class _TerminalScrollGestureHandlerState
    extends State<TerminalScrollGestureHandler> {
  /// The variable that tracks the line offset in last scroll event. Used to
  /// determine how many the scroll events should be sent to the terminal.
  var lastLineOffset = 0;

  /// This variable tracks the last offset where the scroll gesture started.
  /// Used to calculate the cell offset of the terminal mouse event.
  var lastPointerPosition = Offset.zero;

  /// Send a single scroll event to the terminal. If [simulateScroll] is true,
  /// then if the application doesn't recognize mouse wheel events, this method
  /// will simulate scroll events by sending up/down arrow keys.
  void _sendScrollEvent(bool up) {
    final position = widget.getCellOffset(lastPointerPosition);
    widget.terminalListener.mouseEvent(
      MouseScrollEvent(position, dart_tui.Offset(0, up ? -1 : 1)),
    );
  }

  void _onScroll(double offset) {
    final currentLineOffset = offset ~/ widget.getLineHeight();

    final delta = currentLineOffset - lastLineOffset;

    for (var i = 0; i < delta.abs(); i++) {
      _sendScrollEvent(delta < 0);
    }

    lastLineOffset = currentLineOffset;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (event) {
        lastPointerPosition = event.position;
      },
      onPointerDown: (event) {
        lastPointerPosition = event.position;
      },
      child: InfiniteScrollView(onScroll: _onScroll, child: widget.child),
    );
  }
}

/// The function called when the user scrolls the [InfiniteScrollView]. [offset]
/// is the current offset of the scroll view, ranging from [double.negativeInfinity]
/// to [double.infinity].
typedef ScrollCallback = void Function(double offset);

/// A [Scrollable] that can be scrolled infinitely in both directions. When
/// scroll happens, the [onScroll] callback is called with the new offset.
class InfiniteScrollView extends StatelessWidget {
  const InfiniteScrollView({
    super.key,
    required this.onScroll,
    required this.child,
  });

  final ScrollCallback onScroll;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scrollable(
      viewportBuilder: (context, position) {
        return _InfiniteScrollView(
          position: position,
          onScroll: onScroll,
          child: child,
        );
      },
    );
  }
}

class _InfiniteScrollView extends SingleChildRenderObjectWidget {
  const _InfiniteScrollView({
    // super.key,
    super.child,
    required this.position,
    required this.onScroll,
  });

  final ViewportOffset position;

  final ScrollCallback onScroll;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderInfiniteScrollView(position: position, onScroll: onScroll);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderInfiniteScrollView renderObject,
  ) {
    renderObject
      ..position = position
      ..onScroll = onScroll;
  }
}

class _RenderInfiniteScrollView extends RenderShiftedBox {
  _RenderInfiniteScrollView({
    RenderBox? child,
    required ViewportOffset position,
    required ScrollCallback onScroll,
  }) : _position = position,
       _scrollCallback = onScroll,
       super(child);

  ViewportOffset _position;
  set position(ViewportOffset value) {
    if (_position == value) return;
    if (attached) _position.removeListener(markNeedsLayout);
    _position = value;
    if (attached) _position.addListener(markNeedsLayout);
    markNeedsLayout();
  }

  ScrollCallback _scrollCallback;
  set onScroll(ScrollCallback value) {
    if (_scrollCallback == value) return;
    _scrollCallback = value;
    markNeedsLayout();
  }

  void _onScroll() {
    _scrollCallback(_position.pixels);
  }

  @override
  void attach(covariant PipelineOwner owner) {
    super.attach(owner);
    _position.addListener(_onScroll);
  }

  @override
  void detach() {
    super.detach();
    _position.removeListener(_onScroll);
  }

  @override
  void performLayout() {
    child?.layout(constraints, parentUsesSize: true);
    size = child?.size ?? Size.zero;
    _position.applyViewportDimension(size.height);
    _position.applyContentDimensions(double.negativeInfinity, double.infinity);
  }
}

class TerminalGestureHandler extends StatefulWidget {
  const TerminalGestureHandler({
    super.key,
    required this.terminalView,
    this.child,
  });

  final TerminalViewState terminalView;

  final Widget? child;

  @override
  State<TerminalGestureHandler> createState() => _TerminalGestureHandlerState();
}

class _TerminalGestureHandlerState extends State<TerminalGestureHandler> {
  TerminalViewState get terminalView => widget.terminalView;

  RenderTerminal get renderTerminal => terminalView.renderTerminal;

  @override
  Widget build(BuildContext context) {
    return TerminalGestureDetector(
      child: widget.child,
      onSingleTapUp: onSingleTapUp,
      onTapDown: onTapDown,
      onSecondaryTapDown: onSecondaryTapDown,
      onSecondaryTapUp: onSecondaryTapUp,
      onTertiaryTapDown: onSecondaryTapDown,
      onTertiaryTapUp: onSecondaryTapUp,
    );
  }

  void _tapDown(TapDownDetails details, MouseButton button) {
    // Check if the terminal should and can handle the tap down event.
    renderTerminal.mouseEvent(
      button,
      MouseButtonState.pressed,
      details.localPosition,
    );
  }

  void _tapUp(TapUpDetails details, MouseButton button) {
    renderTerminal.mouseEvent(
      button,
      MouseButtonState.released,
      details.localPosition,
    );
  }

  void onTapDown(TapDownDetails details) {
    _tapDown(details, MouseButton.left);
  }

  void onSingleTapUp(TapUpDetails details) {
    _tapUp(details, MouseButton.left);
  }

  void onSecondaryTapDown(TapDownDetails details) {
    _tapDown(details, MouseButton.right);
  }

  void onSecondaryTapUp(TapUpDetails details) {
    _tapUp(details, MouseButton.right);
  }

  void onTertiaryTapDown(TapDownDetails details) {
    _tapDown(details, MouseButton.middle);
  }

  void onTertiaryTapUp(TapUpDetails details) {
    _tapUp(details, MouseButton.right);
  }
}

class TerminalGestureDetector extends StatefulWidget {
  const TerminalGestureDetector({
    super.key,
    this.child,
    this.onSingleTapUp,
    this.onTapUp,
    this.onTapDown,
    this.onSecondaryTapDown,
    this.onSecondaryTapUp,
    this.onTertiaryTapDown,
    this.onTertiaryTapUp,
    this.onLongPressStart,
    this.onLongPressMoveUpdate,
    this.onLongPressUp,
    this.onDragStart,
    this.onDragUpdate,
    this.onDoubleTapDown,
  });

  final Widget? child;

  final GestureTapUpCallback? onTapUp;

  final GestureTapUpCallback? onSingleTapUp;

  final GestureTapDownCallback? onTapDown;

  final GestureTapDownCallback? onSecondaryTapDown;

  final GestureTapUpCallback? onSecondaryTapUp;

  final GestureTapDownCallback? onDoubleTapDown;

  final GestureTapDownCallback? onTertiaryTapDown;

  final GestureTapUpCallback? onTertiaryTapUp;

  final GestureLongPressStartCallback? onLongPressStart;

  final GestureLongPressMoveUpdateCallback? onLongPressMoveUpdate;

  final GestureLongPressUpCallback? onLongPressUp;

  final GestureDragStartCallback? onDragStart;

  final GestureDragUpdateCallback? onDragUpdate;

  @override
  State<TerminalGestureDetector> createState() =>
      _TerminalGestureDetectorState();
}

class _TerminalGestureDetectorState extends State<TerminalGestureDetector> {
  Timer? _doubleTapTimer;

  Offset? _lastTapOffset;

  // True if a second tap down of a double tap is detected. Used to discard
  // subsequent tap up / tap hold of the same tap.
  bool _isDoubleTap = false;

  // The down handler is force-run on success of a single tap and optimistically
  // run before a long press success.
  void _handleTapDown(TapDownDetails details) {
    widget.onTapDown?.call(details);

    if (_doubleTapTimer != null &&
        _isWithinDoubleTapTolerance(details.globalPosition)) {
      // If there was already a previous tap, the second down hold/tap is a
      // double tap down.
      widget.onDoubleTapDown?.call(details);

      _doubleTapTimer!.cancel();
      _doubleTapTimeout();
      _isDoubleTap = true;
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (!_isDoubleTap) {
      widget.onSingleTapUp?.call(details);
      _lastTapOffset = details.globalPosition;
      _doubleTapTimer = Timer(kDoubleTapTimeout, _doubleTapTimeout);
    }
    _isDoubleTap = false;
  }

  void _doubleTapTimeout() {
    _doubleTapTimer = null;
    _lastTapOffset = null;
  }

  bool _isWithinDoubleTapTolerance(Offset secondTapOffset) {
    if (_lastTapOffset == null) {
      return false;
    }

    final Offset difference = secondTapOffset - _lastTapOffset!;
    return difference.distance <= kDoubleTapSlop;
  }

  @override
  Widget build(BuildContext context) {
    final gestures = <Type, GestureRecognizerFactory>{};

    gestures[TapGestureRecognizer] =
        GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
          () => TapGestureRecognizer(debugOwner: this),
          (TapGestureRecognizer instance) {
            instance
              ..onTapDown = _handleTapDown
              ..onTapUp = _handleTapUp
              ..onSecondaryTapDown = widget.onSecondaryTapDown
              ..onSecondaryTapUp = widget.onSecondaryTapUp
              ..onTertiaryTapDown = widget.onTertiaryTapDown
              ..onTertiaryTapUp = widget.onTertiaryTapUp;
          },
        );

    gestures[LongPressGestureRecognizer] =
        GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
          () => LongPressGestureRecognizer(
            debugOwner: this,
            supportedDevices: {
              PointerDeviceKind.touch,
              // PointerDeviceKind.mouse, // for debugging purposes only
            },
          ),
          (LongPressGestureRecognizer instance) {
            instance
              ..onLongPressStart = widget.onLongPressStart
              ..onLongPressMoveUpdate = widget.onLongPressMoveUpdate
              ..onLongPressUp = widget.onLongPressUp;
          },
        );

    gestures[PanGestureRecognizer] =
        GestureRecognizerFactoryWithHandlers<PanGestureRecognizer>(
          () => PanGestureRecognizer(
            debugOwner: this,
            supportedDevices: <PointerDeviceKind>{PointerDeviceKind.mouse},
          ),
          (PanGestureRecognizer instance) {
            instance
              ..dragStartBehavior = DragStartBehavior.down
              ..onStart = widget.onDragStart
              ..onUpdate = widget.onDragUpdate;
          },
        );

    return RawGestureDetector(
      gestures: gestures,
      excludeFromSemantics: true,
      child: widget.child,
    );
  }
}
