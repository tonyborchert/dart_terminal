import 'package:characters/characters.dart';

import 'style.dart';
import 'geometry.dart';

/// List of terminal capabilities.
///
/// These capabilities represent various features and options that may be
/// supported by the terminal, such as color support and mouse event handling.
enum Capability {
  /// Support for [Color.standard] (the basic 8 colors).
  standardColors,

  /// Support for [Color.ansi] (the basic 8 colors + 8 bright colors).
  ansiColors,

  /// Support for [Color.extended] (the 256 colors supported by most xterm compatible terminals).
  extendedColors,

  /// Support for [Color.rgb] (Support for all rgb colors, also called truecolor support).
  trueColors,

  /// If an alternate screen buffer is available
  /// or if for the viewport everything needs to be redrawn
  alternateScreenBuffer,

  /// Support for [TerminalListener.mouseEvent]
  mouse,

  // TODO: currently no support whatsoever => need new event
  bracketedPaste,

  // TODO: currently no support whatsoever
  uft8,

  /// Support for setting [CursorState.blinking] to false
  cursorBlinkingDisable,

  /// Support for [TextEffects.intense]
  intenseTextDecoration,

  /// Support for [TextEffects.italic]
  italicTextDecoration,

  /// Support for [TextEffects.underline]
  underlineTextDecoration,

  /// Support for [TextEffects.doubleUnderline]
  doubleUnderlineTextDecoration,

  /// Support for [TextEffects.crossedOut]
  crossedOutTextDecoration,

  /// Support for [TextEffects.faint]
  faintTextDecoration,

  /// Support for at least [TextEffects.slowBlink]
  /// and possibly [TextEffects.fastBlink]
  textBlinkTextDecoration,
}

/// Support levels for terminal capabilities.
///
/// Used to indicate whether a specific capability is supported, unsupported,
/// or somewhere in between.
enum CapabilitySupport implements Comparable<CapabilitySupport> {
  /// if a capability is very likely to be unsupported
  unsupported,

  /// if there is no information on if a capability is supported or not
  unknown,

  /// features that might work
  assumed,

  /// features that will work with high degree of reliability
  supported;

  @override
  int compareTo(CapabilitySupport other) => index.compareTo(other.index);
}

/// System signals that can be handled by the terminal application.
///
/// These signals correspond to standard POSIX signals that the application
/// may need to respond to.
enum AllowedSignal {
  /// Hangup detected on controlling terminal
  sighup,

  /// Interrupt from keyboard (Ctrl+C)
  sigint,

  /// Termination signal
  sigterm,

  /// User-defined signal 1
  sigusr1,

  /// User-defined signal 2
  sigusr2,
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

// TODO: add ansi support
enum CursorType { block, underline, verticalBar }

/// Note: button 4-7 are used for scrolling
enum MouseButton { left, right, middle, button8, button9, button10, button11 }

enum MouseButtonState { pressed, released }

/// Base class for mouse events in the terminal.
///
/// Provides common properties for all mouse-related events including
/// modifier key states and cursor position.
sealed class MouseEvent {
  /// Whether the shift key was pressed during the event
  final bool isShiftPressed;

  /// Whether the meta (command/windows) key was pressed
  final bool isMetaPressed;

  /// Whether the control key was pressed
  final bool isCtrlPressed;

  /// The position of the mouse cursor when the event occurred
  final Position position;

  const MouseEvent(
    this.position, {
    this.isShiftPressed = false,
    this.isMetaPressed = false,
    this.isCtrlPressed = false,
  });

  @override
  bool operator ==(Object other) =>
      other is MouseEvent &&
      isShiftPressed == other.isShiftPressed &&
      isMetaPressed == other.isMetaPressed &&
      isCtrlPressed == other.isCtrlPressed &&
      position == other.position;
}

/// Represents a mouse button that is pressed or has been released.
///
/// Includes information about which button was involved and the type of press.
final class MousePressEvent extends MouseEvent {
  /// The mouse button that triggered the event
  final MouseButton button;

  /// If the button is pressed [MouseButtonState.pressed],
  /// released [MouseButtonState.released],
  final MouseButtonState buttonState;

  const MousePressEvent(
    super.position,
    this.button,
    this.buttonState, {
    super.isMetaPressed,
    super.isCtrlPressed,
    super.isShiftPressed,
  });

  @override
  bool operator ==(Object other) =>
      other is MousePressEvent &&
      button == other.button &&
      buttonState == other.buttonState &&
      super == (other);

  @override
  String toString() {
    return '(${position.x},${position.y},${button.name},${buttonState.name}'
        '${isShiftPressed == true ? ',shift' : ''}'
        '${isCtrlPressed == true ? ',ctrl' : ''}'
        '${isMetaPressed == true ? ',meta' : ''})';
  }
}

/// Represents mouse movement with or without press.
final class MouseMotionEvent extends MouseEvent {
  /// The button that is being pressed,
  /// if [button] is `null` this means the mouse is hovering
  final MouseButton? button;

  bool get isHover => button == null;

  const MouseMotionEvent(
    super.position,
    this.button, {
    super.isShiftPressed,
    super.isMetaPressed,
    super.isCtrlPressed,
  });

  const MouseMotionEvent.hover(
    super.position, {
    super.isShiftPressed,
    super.isMetaPressed,
    super.isCtrlPressed,
  }) : this.button = null;

  @override
  bool operator ==(Object other) =>
      other is MouseMotionEvent && button == other.button && super == (other);

  @override
  String toString() {
    return '(${position.x},${position.y}'
        '${button != null ? ',${button!.name}' : ''},hover'
        '${isShiftPressed == true ? ',shift' : ''}'
        '${isCtrlPressed == true ? ',ctrl' : ''}'
        '${isMetaPressed == true ? ',meta' : ''})';
  }
}

/// Represents mouse wheel scrolling.
///
/// Contains information about the scroll amount in both x and y directions.
final class MouseScrollEvent extends MouseEvent {
  /// The amount of scrolling in the x direction and y direction
  final Offset vec;

  bool get isScrollUp => vec.dy < 0;
  bool get isScrollDown => vec.dy > 0;
  bool get isScrollLeft => vec.dx < 0;
  bool get isScrollRight => vec.dx > 0;

  const MouseScrollEvent(
    super.position,
    this.vec, {
    super.isShiftPressed,
    super.isMetaPressed,
    super.isCtrlPressed,
  });

  @override
  bool operator ==(Object other) =>
      other is MouseScrollEvent && vec == other.vec && super == (other);

  @override
  String toString() {
    final directions = [
      if (isScrollUp) 'up',
      if (isScrollDown) 'down',
      if (isScrollLeft) 'left',
      if (isScrollRight) 'right',
    ];
    return '(${position.x},${position.y}'
        '${directions.isNotEmpty ? ',${directions.join('/')}' : ''}'
        '${isShiftPressed == true ? ',Shift' : ''}'
        '${isCtrlPressed == true ? ',Ctrl' : ''}'
        '${isMetaPressed == true ? ',Meta' : ''})';
  }
}

/// Represents keyboard input events.
///
/// This is a sealed class with different implementations for various types
/// of keyboard inputs:
/// - [UnicodeChar]: Represents a single, non-ascii Unicode character input.
/// - [KeyStroke]: Represents ascii or non-printable key inputs with modifiers.
/// - [PasteTextInput]: Represents pasted text input.
sealed class KeyboardInput {
  bool get isPrintable => stringRepresentation != null;
  String? get stringRepresentation;

  const KeyboardInput();
}

/// Represents a single Unicode character input from the keyboard.
///
/// Contains the character and indicates that it is printable.
final class UnicodeChar extends KeyboardInput {
  final Characters character;
  bool get isPrintable => true;

  UnicodeChar(this.character) : assert(character.length == 1);

  @override
  String get stringRepresentation => character.toString();
}

final class PasteTextInput extends KeyboardInput {
  final String rawStringRepresentation;
  final String sanitizedStringRepresentation;
  final bool fromBracketedPaste;
  bool get isPrintable => true;

  PasteTextInput({
    required this.rawStringRepresentation,
    required this.sanitizedStringRepresentation,
    this.fromBracketedPaste = false,
  });

  // TODO: maybe sanitize?
  @override
  String get stringRepresentation => rawStringRepresentation;
}

/// Keys that can be used in keyboard input.
enum Key {
  // -- ASCII KEYS --
  carriageReturn("carriage return", "\r"),
  enter("enter", "\n"),
  tab("tab", "\t"),
  escape("escape"),

  // 32–47
  space("space", " "),
  exclamation("!"),
  quote('"'),
  hash("#"),
  dollar("\$"),
  percent("%"),
  ampersand("&"),
  apostrophe("'"),
  paren_left("("),
  paren_right(")"),
  asterisk("*"),
  plus("+"),
  comma(","),
  minus("-"),
  dot("."),
  slash("/"),

  // 48–57
  digit_0("0"),
  digit_1("1"),
  digit_2("2"),
  digit_3("3"),
  digit_4("4"),
  digit_5("5"),
  digit_6("6"),
  digit_7("7"),
  digit_8("8"),
  digit_9("9"),

  // 58–64
  colon(":"),
  semicolon(";"),
  less_than("<"),
  equals("="),
  greater_than(">"),
  question("?"),
  at("@"),

  // here we skip uppercase letters A-Z (65-90)

  // 91–96
  bracket_left("["),
  backslash("\\"),
  bracket_right("]"),
  caret("^"),
  underscore("_"),
  backtick("`"),

  // 97-122
  a,
  b,
  c,
  d,
  e,
  f,
  g,
  h,
  i,
  j,
  k,
  l,
  m,
  n,
  o,
  p,
  q,
  r,
  s,
  t,
  u,
  v,
  w,
  x,
  y,
  z,

  // 123–126
  brace_left("{"),
  pipe("|"),
  brace_right("}"),
  tilde("~"),

  // 127
  backspace("backspace"),
  // -- NON ASCII KEYS --

  // keypad digits (can some times be differentiated)
  keypad_0("0"),
  keypad_1("1"),
  keypad_2("2"),
  keypad_3("3"),
  keypad_4("4"),
  keypad_5("5"),
  keypad_6("6"),
  keypad_7("7"),
  keypad_8("8"),
  keypad_9("9"),

  // f keys
  F1,
  F2,
  F3,
  F4,
  F5,
  F6,
  F7,
  F8,
  F9,
  F10,
  F11,
  F12,

  // navigation
  end("end"),
  home("home"),
  arrowUp("arrow up"),
  arrowDown("arrow down"),
  arrowRight("arrow right"),
  arrowLeft("arrow left"),
  pageUp("page up"),
  pageDown("page down"),

  // editing
  clear("clear"),
  insert("insert"),
  delete("delete");

  final String? _description;
  final String? _printable;

  const Key([String? description, String? printable])
    : this._description = description,
      _printable = printable ?? description;

  @override
  String toString() => _description ?? name;

  bool get isPrintable => isDigit || isLetter || isWhitespace || isPunctuation;

  bool get isSafePrintable =>
      isDigit || isLetter || isSafeWhitespace || isPunctuation;

  bool get isLetter => a.index <= index || index <= z.index;

  bool get isDigit => isDigit || isKeypadDigit;

  bool get isNormalDigit => digit_0.index < index && index <= digit_9.index;

  bool get isKeypadDigit => keypad_0.index < index && index <= keypad_9.index;

  bool get isWhitespace => carriageReturn.index < index && index <= space.index;

  bool get isSafeWhitespace => this == space || this == tab || this == enter;

  bool get isPunctuation {
    if (exclamation.index <= index && index <= slash.index) return true;
    if (colon.index <= index && index <= backtick.index) return true;
    if (bracket_left.index <= index && index <= tilde.index) return true;
    return false;
  }

  bool get isFunctionKey {
    return F1.index <= index && index <= F12.index;
  }

  bool get isDirection => arrowUp.index <= index && index <= pageDown.index;

  String get printable => _printable ?? name;

  String? get letter => isLetter ? name : null;

  int? get digit => isNormalDigit
      ? index - digit_0.index
      : (isKeypadDigit ? index - keypad_0.index : null);

  int? get functionKeyNumber => isFunctionKey ? index - F1.index + 1 : null;

  String? get whiteSpace => isWhitespace ? _printable! : null;

  Offset? get direction => switch (this) {
    Key.arrowUp => const Offset(0, -1),
    Key.arrowDown => const Offset(0, 1),
    Key.arrowLeft => const Offset(-1, 0),
    Key.arrowRight => const Offset(1, 0),
    Key.pageUp => const Offset(0, -1),
    Key.pageDown => const Offset(0, 1),
    _ => null,
  };

  /// [codepoint] has to be lowercase
  static Key? tryGetAsciiKey(int codepoint) => switch (codepoint) {
    9 => tab,
    10 => enter,
    13 => carriageReturn,
    27 => escape,
    >= 32 && <= 64 => Key.values[codepoint - 32 + space.index],
    >= 91 && <= 127 => Key.values[codepoint - 91 + bracket_left.index],
    _ => null,
  };

  factory Key.F(int number) {
    assert(1 <= number && number <= 12);
    return Key.values[number + F1.index];
  }

  /// get letter from 0-25
  factory Key.letter(int letter) {
    assert(0 <= letter && letter <= 25);
    return Key.values[letter + Key.a.index];
  }

  factory Key.digit(int digit, {bool keypad = false}) {
    assert(0 <= digit && digit < 10);
    if (keypad) {
      return Key.values[digit + keypad_0.index];
    }
    return Key.values[digit + digit_0.index];
  }
}

/// Represents an ascii or non-printable key input with optional modifier keys.
final class KeyStroke extends KeyboardInput {
  final Key key;
  final bool isShiftPressed, isMetaPressed, isCtrlPressed;

  const KeyStroke(
    this.key, {
    this.isShiftPressed = false,
    this.isMetaPressed = false,
    this.isCtrlPressed = false,
  });

  bool get isModified => isShiftPressed || isMetaPressed || isCtrlPressed;

  @override
  bool get isPrintable => key.isPrintable && !isMetaPressed && !isCtrlPressed;

  String? get stringRepresentation => isPrintable
      ? (isShiftPressed ? key.printable : key.printable.toUpperCase())
      : null;

  bool operator ==(Object other) =>
      other is KeyStroke &&
      key == other.key &&
      isShiftPressed == other.isShiftPressed &&
      isMetaPressed == other.isMetaPressed &&
      isCtrlPressed == other.isCtrlPressed;

  bool operator >=(covariant KeyStroke other) =>
      key == other.key &&
      (isShiftPressed || !other.isShiftPressed) &&
      (isMetaPressed || !other.isMetaPressed) &&
      (isCtrlPressed || !other.isCtrlPressed);

  bool operator <=(covariant KeyStroke other) => other >= this;

  @override
  int get hashCode =>
      key.hashCode ^
      isShiftPressed.hashCode ^
      isMetaPressed.hashCode ^
      isCtrlPressed.hashCode;

  static KeyStroke? tryGetAsciiKeyStroke(String str) {
    if (str.length != 1) return null;
    int codeUnit = str.codeUnitAt(0);
    bool isShiftPressed = false;
    if (codeUnit >= 65 && codeUnit <= 90) {
      isShiftPressed = true;
      codeUnit += 32;
    }
    final key = Key.tryGetAsciiKey(codeUnit);
    return key != null ? KeyStroke(key, isShiftPressed: isShiftPressed) : null;
  }

  @override
  String toString() {
    final modifiers = [
      if (isCtrlPressed) 'Ctrl',
      if (isMetaPressed) 'Meta',
      if (isShiftPressed) 'Shift',
    ];
    return 'KeyStroke(${modifiers.isNotEmpty ? '${modifiers.join('+')}+' : ''}${key.toString()})';
  }
}

/// Predefined common key strokes for easy access.
abstract final class KeyStrokes {
  static const a = KeyStroke(Key.a);
  static const b = KeyStroke(Key.b);
  static const c = KeyStroke(Key.c);
  static const d = KeyStroke(Key.d);
  static const e = KeyStroke(Key.e);
  static const f = KeyStroke(Key.f);
  static const g = KeyStroke(Key.g);
  static const h = KeyStroke(Key.h);
  static const i = KeyStroke(Key.i);
  static const j = KeyStroke(Key.j);
  static const k = KeyStroke(Key.k);
  static const l = KeyStroke(Key.l);
  static const m = KeyStroke(Key.m);
  static const n = KeyStroke(Key.n);
  static const o = KeyStroke(Key.o);
  static const p = KeyStroke(Key.p);
  static const q = KeyStroke(Key.q);
  static const r = KeyStroke(Key.r);
  static const s = KeyStroke(Key.s);
  static const t = KeyStroke(Key.t);
  static const u = KeyStroke(Key.u);
  static const v = KeyStroke(Key.v);
  static const w = KeyStroke(Key.w);
  static const x = KeyStroke(Key.x);
  static const y = KeyStroke(Key.y);
  static const z = KeyStroke(Key.z);

  static const A = KeyStroke(Key.a, isShiftPressed: true);
  static const B = KeyStroke(Key.b, isShiftPressed: true);
  static const C = KeyStroke(Key.c, isShiftPressed: true);
  static const D = KeyStroke(Key.d, isShiftPressed: true);
  static const E = KeyStroke(Key.e, isShiftPressed: true);
  static const F = KeyStroke(Key.f, isShiftPressed: true);
  static const G = KeyStroke(Key.g, isShiftPressed: true);
  static const H = KeyStroke(Key.h, isShiftPressed: true);
  static const I = KeyStroke(Key.i, isShiftPressed: true);
  static const J = KeyStroke(Key.j, isShiftPressed: true);
  static const K = KeyStroke(Key.k, isShiftPressed: true);
  static const L = KeyStroke(Key.l, isShiftPressed: true);
  static const M = KeyStroke(Key.m, isShiftPressed: true);
  static const N = KeyStroke(Key.n, isShiftPressed: true);
  static const O = KeyStroke(Key.o, isShiftPressed: true);
  static const P = KeyStroke(Key.p, isShiftPressed: true);
  static const Q = KeyStroke(Key.q, isShiftPressed: true);
  static const R = KeyStroke(Key.r, isShiftPressed: true);
  static const S = KeyStroke(Key.s, isShiftPressed: true);
  static const T = KeyStroke(Key.t, isShiftPressed: true);
  static const U = KeyStroke(Key.u, isShiftPressed: true);
  static const V = KeyStroke(Key.v, isShiftPressed: true);
  static const W = KeyStroke(Key.w, isShiftPressed: true);
  static const X = KeyStroke(Key.x, isShiftPressed: true);
  static const Y = KeyStroke(Key.y, isShiftPressed: true);
  static const Z = KeyStroke(Key.z, isShiftPressed: true);

  // Control keys (first 26 ascii symbols)
  static const ctrlSpace = KeyStroke(Key.space, isCtrlPressed: true); // NULL
  static const ctrlA = KeyStroke(Key.a, isCtrlPressed: true);
  static const ctrlB = KeyStroke(Key.b, isCtrlPressed: true);
  static const ctrlC = KeyStroke(Key.c, isCtrlPressed: true); // Break
  static const ctrlD = KeyStroke(Key.d, isCtrlPressed: true); // End of File
  static const ctrlE = KeyStroke(Key.e, isCtrlPressed: true);
  static const ctrlF = KeyStroke(Key.f, isCtrlPressed: true);
  static const ctrlG = KeyStroke(Key.g, isCtrlPressed: true); // Bell
  // often not possible (interpreted as backspace)
  static const ctrlH = KeyStroke(Key.h, isCtrlPressed: true);
  // often not possible (interpreted as tab)
  static const ctrlI = KeyStroke(Key.i, isCtrlPressed: true);
  static const ctrlJ = KeyStroke(Key.j, isCtrlPressed: true);
  static const ctrlK = KeyStroke(Key.k, isCtrlPressed: true);
  static const ctrlL = KeyStroke(Key.l, isCtrlPressed: true);
  // often not possible (interpreted as enter)
  static const ctrlM = KeyStroke(Key.m, isCtrlPressed: true);
  static const ctrlN = KeyStroke(Key.n, isCtrlPressed: true);
  static const ctrlO = KeyStroke(Key.o, isCtrlPressed: true);
  static const ctrlP = KeyStroke(Key.p, isCtrlPressed: true);
  static const ctrlQ = KeyStroke(Key.q, isCtrlPressed: true);
  static const ctrlR = KeyStroke(Key.r, isCtrlPressed: true);
  static const ctrlS = KeyStroke(Key.s, isCtrlPressed: true);
  static const ctrlT = KeyStroke(Key.t, isCtrlPressed: true);
  static const ctrlU = KeyStroke(Key.u, isCtrlPressed: true);
  static const ctrlV = KeyStroke(Key.v, isCtrlPressed: true);
  static const ctrlW = KeyStroke(Key.w, isCtrlPressed: true);
  static const ctrlX = KeyStroke(Key.x, isCtrlPressed: true);
  static const ctrlY = KeyStroke(Key.y, isCtrlPressed: true);
  static const ctrlZ = KeyStroke(Key.z, isCtrlPressed: true); // Suspend
  // f keys
  static const F1 = KeyStroke(Key.F1);
  static const F2 = KeyStroke(Key.F2);
  static const F3 = KeyStroke(Key.F3);
  static const F4 = KeyStroke(Key.F4);
  static const F5 = KeyStroke(Key.F5);
  static const F6 = KeyStroke(Key.F6);
  static const F7 = KeyStroke(Key.F7);
  static const F8 = KeyStroke(Key.F8);
  static const F9 = KeyStroke(Key.F9);
  static const F10 = KeyStroke(Key.F10);
  static const F11 = KeyStroke(Key.F11);
  static const F12 = KeyStroke(Key.F12);
  // editing
  static const carriageReturn = KeyStroke(Key.carriageReturn);
  static const enter = KeyStroke(Key.enter);
  static const tab = KeyStroke(Key.tab);
  static const space = KeyStroke(Key.space);
  static const backspace = KeyStroke(Key.backspace);
  static const clear = KeyStroke(Key.clear);
  static const insert = KeyStroke(Key.insert);
  static const delete = KeyStroke(Key.delete);
  // navigation
  static const escape = KeyStroke(Key.escape);
  static const end = KeyStroke(Key.end);
  static const home = KeyStroke(Key.home);
  // movement
  static const arrowUp = KeyStroke(Key.arrowUp);
  static const arrowDown = KeyStroke(Key.arrowDown);
  static const arrowRight = KeyStroke(Key.arrowRight);
  static const arrowLeft = KeyStroke(Key.arrowLeft);
  static const pageUp = KeyStroke(Key.pageUp);
  static const pageDown = KeyStroke(Key.pageDown);
}

/// Represents raw terminal input data.
class RawTerminalInput {
  final List<int>? data;
  final String? encodedData;

  RawTerminalInput(this.data, this.encodedData);
}
