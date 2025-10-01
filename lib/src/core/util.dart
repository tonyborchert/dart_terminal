// Project imports:

// Project imports:
import 'primitives.dart';
import 'geometry.dart';
import 'terminal.dart';

class LambdaTerminalListener implements TerminalListener {
  void Function(ControlCharacter) onControlCharacter;
  // ignore: avoid_positional_boolean_parameters
  void Function(bool) onFocusChange;
  void Function(String) onInput;
  void Function(MouseEvent) onMouseEvent;
  void Function(Size) onScreenResize;
  void Function(AllowedSignal) onSignal;

  static void _(_) {}

  LambdaTerminalListener({
    this.onControlCharacter = _,
    // ignore: avoid_positional_boolean_parameters
    this.onFocusChange = _,
    this.onInput = _,
    this.onMouseEvent = _,
    this.onScreenResize = _,
    this.onSignal = _,
  });

  @override
  void controlCharacter(ControlCharacter controlCharacter) =>
      onControlCharacter(controlCharacter);

  @override
  void focusChange(bool isFocused) => onFocusChange(isFocused);

  @override
  void input(String s) => onInput(s);

  @override
  void mouseEvent(MouseEvent event) => onMouseEvent(event);

  @override
  void screenResize(Size size) => onScreenResize(size);

  @override
  void signal(AllowedSignal signal) => onSignal(signal);
}

class DefaultTerminalListener implements TerminalListener {
  const DefaultTerminalListener();

  @override
  void controlCharacter(ControlCharacter controlCharacter) {}

  @override
  void input(String s) {}

  @override
  void screenResize(Size size) {}

  @override
  void signal(AllowedSignal signal) {}

  @override
  void focusChange(bool isFocused) {}

  @override
  void mouseEvent(MouseEvent event) {}
}
