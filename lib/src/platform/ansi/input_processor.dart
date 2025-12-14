// Meta key regex
import 'dart:async' as async;
import 'dart:convert';
import 'package:characters/characters.dart';
import 'package:dart_terminal/core.dart';

class DeviceAttributes {
  final String daType; // '?' or '>'
  final int type; // Pp
  final int version; // Pv
  final int extra; // Pc (optional)

  DeviceAttributes({
    required this.daType,
    required this.type,
    required this.version,
    required this.extra,
  });

  @override
  String toString() =>
      'DeviceAttributes(type: $type, version: $version, extra: $extra)';
}

extension on String {
  int get codeUnit {
    assert(length == 1);
    return codeUnitAt(0);
  }
}

final _a = "a".codeUnit;
final _z = "z".codeUnit;
final _A = "A".codeUnit;
final _Z = "Z".codeUnit;
final _0 = "0".codeUnit;
final _9 = "9".codeUnit;

class InputProcessor {
  void Function(String input)? pasteListener;

  void Function(String input)? charListener;

  void Function(MouseEvent mouseEvent)? mouseListener;

  void Function(KeyStroke)? keyStrokeListener;

  void Function(bool)? focusListener;

  void Function(Position)? cursorPositionQueryListener;

  void Function(String)? unhandledListener;

  void Function(String)? handledStringListener;

  void Function(DeviceAttributes)? deviceAttributesListener;

  bool awaitingCursorPositionAnswer = false;

  late Stream<List<int>> inputStream;
  late final async.StreamSubscription<List<int>> _inputStreamSubscription;
  final Duration bracketedPasteTimeoutDuration;
  final Encoding encoding;
  bool _waitingForBracketedPaste = false;
  late StringBuffer _bracketedPasteBuffer;
  async.Timer? _bracketedPasteTimeoutTimer;
  MouseButton? lastPressedButton;

  InputProcessor({
    this.encoding = utf8,
    this.bracketedPasteTimeoutDuration = const Duration(milliseconds: 50),
  });

  void startListening(Stream<List<int>> inputStream) {
    _inputStreamSubscription = inputStream.listen(processInput);
  }

  Future<void> stopListening() => _inputStreamSubscription.cancel();

  String decode(List<int> buf) {
    if (encoding == utf8) {
      if (buf.length == 1 && buf[0] > 127) {
        buf[0] -= 128;
        return '\x1b' + utf8.decode(buf, allowMalformed: true);
      } else {
        return utf8.decode(buf, allowMalformed: true);
      }
    } else {
      if (buf.length == 1 && buf[0] > 127) {
        buf[0] -= 128;
        return '\x1b' + encoding.decode(buf);
      } else {
        return encoding.decode(buf);
      }
    }
  }

  void processInput(List<int> buf) {
    final s = decode(buf);

    // also convert beginning if it is C1 CSI to normal CSI?
    if (!(tryProcessBracketedPaste(s) ||
        tryProcessFocusEvent(s) ||
        tryProcessCursorPositionAnswer(s) ||
        tryProcessMouseEvents(s, buf))) {
      processRestInput(s);
    } else {
      handledStringListener?.call(s);
    }
  }

  // Matches the start of a bracketed paste
  static final bracketedPasteBeginRe = RegExp(r'^\x1b\[200~');

  // Matches the end of a bracketed paste
  static final bracketedPasteEndRe = RegExp(r'\x1b\[201~$');

  bool tryProcessBracketedPaste(String s) {
    if (s.length < 6 && !_waitingForBracketedPaste) return false;
    bool hasMatched = false;
    if (bracketedPasteBeginRe.hasMatch(s)) {
      s = s.substring(6);
      _waitingForBracketedPaste = true;
      _bracketedPasteBuffer = StringBuffer();
      hasMatched = true;
    }
    if (_waitingForBracketedPaste) {
      _bracketedPasteTimeoutTimer?.cancel();
      if (bracketedPasteEndRe.hasMatch(s)) {
        _bracketedPasteBuffer.write(s.substring(0, s.length - 6));
        pasteListener?.call(_bracketedPasteBuffer.toString());
        _bracketedPasteBuffer.clear();
        _waitingForBracketedPaste = true;
      } else {
        _bracketedPasteBuffer.write(s);
        _bracketedPasteTimeoutTimer = async.Timer(
          bracketedPasteTimeoutDuration,
          () {
            _waitingForBracketedPaste = false;
            pasteListener?.call(_bracketedPasteBuffer.toString());
            _bracketedPasteBuffer.clear();
          },
        );
      }
      hasMatched = true;
    }
    return hasMatched;
  }

  // Matches focus in or focus out events
  static final focusEventRe = RegExp(r'\x1b\[([IO])');

  bool tryProcessFocusEvent(String s) {
    if (s.length < 3) return false;
    final match = focusEventRe.firstMatch(s);
    if (match == null) return false;

    final event = match.group(1)!;
    if (event == 'I') {
      focusListener?.call(true);
    } else if (event == 'O') {
      focusListener?.call(false);
    }
    return true;
  }

  static final cursorPositionRe = RegExp(r'^\x1b\[(\d+);(\d+)R$');

  bool tryProcessCursorPositionAnswer(String s) {
    if (!awaitingCursorPositionAnswer) return false;
    if (s.length < 6) return false;
    final match = cursorPositionRe.firstMatch(s);
    if (match == null) return false;
    awaitingCursorPositionAnswer = false;

    final y = int.parse(match.group(1)!); // row
    final x = int.parse(match.group(2)!); // column
    cursorPositionQueryListener?.call(Position(x - 1, y - 1));
    return true;
  }

  static final daRe = RegExp(r'^\x1b\[(\?|\>)(\d+);(\d+);(\d+)c$');
  bool tryProcessDeviceAttributes(String s) {
    if (s.length < 8) return false;
    final match = daRe.firstMatch(s);
    if (match == null) return false;

    final typeChar = match.group(1)!;
    final pp = int.parse(match.group(2)!);
    final pv = int.parse(match.group(3)!);
    final pc = int.parse(match.group(4)!);

    final attrs = DeviceAttributes(
      daType: typeChar,
      type: pp,
      version: pv,
      extra: pc,
    );
    deviceAttributesListener?.call(attrs);
    return true;
  }

  // See: http://invisible-island.net/xterm/ctlseqs/ctlseqs.html#h3-X10-compatibility-mode
  // handles DECSET 9, 1000, 1002, 1003, 1005
  static final mouseX10StandardRe = RegExp(r"^\x1b\[M([\x00\u0020-\uffff]{3})");
  // handles DECSET 1015
  static final mouseURxvtRe = RegExp(r"^\x1b\[(\d+;\d+;\d+)M");
  // handles DECSET 1006
  static final mouseSgrRe = RegExp(r"^\x1b\[<(\d+;\d+;\d+)([mM])");
  static final mouseDECRe = RegExp(r"^\x1b\[<(\d+;\d+;\d+;\d+)&w");
  static final mouseVT300 = RegExp(r"^\x1b\[24([0135])~\[(\d+),(\d+)\]\r");

  bool tryProcessMouseEvents(String s, List<int> buf) {
    if (s.length < 6) return false;
    if (s.length < 12) return tryProcessMouseEvent(s, buf);

    int startOfEvent = -1;
    bool foundMouseEvent = false;
    for (int i = 0; i <= buf.length; i++) {
      if (i == buf.length || buf[i] == 0x1b) {
        if (startOfEvent >= 0) {
          final eventBuff = buf.sublist(startOfEvent, i);
          if (tryProcessMouseEvent(decode(eventBuff), eventBuff)) {
            foundMouseEvent = true;
          }
        }
        startOfEvent = i;
      }
    }
    return foundMouseEvent;
  }

  bool tryProcessMouseEvent(String s, List<int> buf) {
    // Fix malformed ones
    var bx = s.codeUnitAt(4);
    var by = s.codeUnitAt(5);
    if (buf[0] == 0x1b &&
        buf[1] == 0x5b &&
        buf[2] == 0x4d &&
        ( /*this.isVTE || */ bx >= 65533 ||
            by >= 65533 ||
            (bx > 0x00 && bx < 0x20) ||
            (by > 0x00 && by < 0x20) ||
            (buf[4] > 223 && buf[4] < 248 && buf.length == 6) ||
            (buf[5] > 223 && buf[5] < 248 && buf.length == 6))) {
      int b = buf[3], x = buf[4], y = buf[5];

      // unsigned char overflow.
      if (x < 0x20) x += 0xff;
      if (y < 0x20) y += 0xff;

      // Convert the coordinates into a
      // properly formatted x10 utf8 sequence.
      s =
          '\x1b[M' +
          String.fromCharCode(b) +
          String.fromCharCode(x) +
          String.fromCharCode(y);
    }
    Match? match = mouseX10StandardRe.matchAsPrefix(s);
    if (match != null) {
      int b = match[1]!.codeUnitAt(0) - 32,
          x = match[1]!.codeUnitAt(1) - 32,
          y = match[1]!.codeUnitAt(2) - 32;
      if (x == 0) x = 255;
      if (y == 0) y = 255;
      _xtermMouseEvent(b, x, y);
      return true;
    }
    bool isURxvt = false;
    match = mouseURxvtRe.matchAsPrefix(s);
    if (match != null) {
      isURxvt = true;
    } else {
      match = mouseSgrRe.matchAsPrefix(s);
    }
    if (match != null) {
      final params = match[1]!.split(";");
      int b = int.parse(params[0]),
          x = int.parse(params[1]),
          y = int.parse(params[2]);
      if (isURxvt) b -= 32;
      final isPressed = match.groupCount == 2 ? match[2] != 'm' : null;
      _xtermMouseEvent(b, x, y, isPressed: isPressed);
      return true;
    }
    match = mouseDECRe.matchAsPrefix(s);
    if (match != null) {
      final params = match[1]!.split(";");
      int b = int.parse(params[0]),
          x = int.parse(params[1]),
          y = int.parse(params[2]);
      final button = switch (b) {
        2 => 1,
        4 => 2,
        6 => 3,
        _ => null,
      };
      _rawMouseEvent(
        buttonNumber: button,
        isMotion: false,
        position: Position(x - 1, y - 1),
        isPressed: b == 3,
      );
      return true;
    }
    match = mouseVT300.matchAsPrefix(s);
    if (match != null) {
      int b = int.parse(match[1]!),
          x = int.parse(match[2]!),
          y = int.parse(match[3]!);
      final button = switch (b) {
        1 => 1,
        2 => 2,
        5 => 3,
        _ => null,
      };
      if (button != null) {
        _rawMouseEvent(
          buttonNumber: button,
          isMotion: false,
          position: Position(x - 1, y - 1),
          isPressed: true,
        );
      }
      return true;
    }
    return false;
  }

  void _xtermMouseEvent(int b, int x, int y, {bool? isPressed}) {
    final pos = Position(x - 1, y - 1);
    final lowerButton = b & 3;
    final extraButtons1 = b & 64 != 0; // for buttons 4-7 (scrollButtons)
    final extraButtons2 = (b & 128 != 0) && !extraButtons1; // for buttons 8-11
    late int? buttonNumber;
    if (extraButtons1 || extraButtons2) {
      buttonNumber =
          lowerButton + (extraButtons1 ? 4 : 0) + (extraButtons2 ? 8 : 0);
    } else if (lowerButton == 3) {
      buttonNumber = null;
    } else {
      buttonNumber = lowerButton + 1;
    }
    final shift = b & 4 != 0, meta = b & 8 != 0, ctrl = b & 16 != 0;
    final isMotion = b & 32 != 0;

    _rawMouseEvent(
      buttonNumber: buttonNumber,
      isMotion: isMotion,
      position: pos,
      isPressed: isPressed ?? buttonNumber != null,
      meta: meta,
      shift: shift,
      ctrl: ctrl,
    );
  }

  // 1:left, 2:middle, 3:right, 4-7:scroll, 8-11: extended,
  // null == unknown (for example on some terminals if the button releases)
  void _rawMouseEvent({
    int? buttonNumber,
    required Position position,
    required bool isPressed,
    bool isMotion = false,
    bool meta = false,
    bool shift = false,
    bool ctrl = false,
  }) {
    final scrollVec = switch (buttonNumber) {
      4 => Offset(0, -1),
      5 => Offset(0, 1),
      6 => Offset(1, 0),
      7 => Offset(-1, 0),
      _ => Offset.zero,
    };
    if (scrollVec != Offset.zero) {
      mouseListener?.call(
        MouseScrollEvent(
          position,
          scrollVec,
          isShiftPressed: shift,
          isMetaPressed: meta,
          isCtrlPressed: ctrl,
        ),
      );
      return;
    }
    MouseButton? button = switch (buttonNumber) {
      1 => MouseButton.left,
      2 => MouseButton.middle,
      3 => MouseButton.right,
      8 => MouseButton.button8,
      9 => MouseButton.button9,
      10 => MouseButton.button10,
      11 => MouseButton.button11,
      _ => null,
    };
    if (isMotion ||
        (!isPressed && button == null && lastPressedButton == null)) {
      mouseListener?.call(
        MouseMotionEvent(
          position,
          button,
          isShiftPressed: shift,
          isMetaPressed: meta,
          isCtrlPressed: ctrl,
        ),
      );
      return;
    }
    if (button == null) {
      if (!isPressed) {
        button = lastPressedButton;
        lastPressedButton = null;
      }
    } else if (isPressed) {
      lastPressedButton = button;
    }
    if (button == null) {
      // not possible as if button isPressed => button != null
      throw ArgumentError();
    }
    final state = isPressed
        ? MouseButtonState.pressed
        : MouseButtonState.released;
    mouseListener?.call(
      MousePressEvent(
        position,
        button,
        state,
        isShiftPressed: shift,
        isMetaPressed: meta,
        isCtrlPressed: ctrl,
      ),
    );
  }

  static final metaKeyCodeReAnywhere = RegExp(r'(?:\x1b)([a-zA-Z0-9])');
  static final metaKeyCodeRe = RegExp('^${metaKeyCodeReAnywhere.pattern}\$');

  // Function key regex
  static final functionKeyPatterns = [
    r'(\d+)(?:;(\d+))?([~^$])', // numeric + optional modifier + symbol
    r'(?:M([@ #!a`])(.)(.))', // mouse
    r'(?:1;)?(\d+)?([a-zA-Z])', // optional 1;, number?, letter
  ];

  static final functionKeyCodeReAnywhere = RegExp(
    r'(?:\x1b+)(O|N|\[|\[\[)(?:' + functionKeyPatterns.join('|') + r')',
  );

  static final functionKeyCodeRe = RegExp(
    '^${functionKeyCodeReAnywhere.pattern}',
  );

  // Escape code regex
  static final escapeCodeReAnywhere = RegExp(
    [
      functionKeyCodeReAnywhere.pattern,
      metaKeyCodeReAnywhere.pattern,
      r'\x1b[\x00-\x7F]', // any ESC + char
    ].join('|'),
  );

  // general escape code for any csi escape code
  static final csiRe = RegExp(
    r'(?:\x1B\[|\x9B)' // CSI introducer (7-bit ESC[ or 8-bit 0x9B)
    r'([\x30-\x3F]*)' // P1...Pn  parameter bytes  (column 3)
    r'([\x20-\x2F]*)' // I1...Im  intermediate bytes (column 2)
    r'([\x40-\x7E])', // F        final byte (columns 4-7, excl. 7/15)
  );

  void processRestInput(String s) {
    while (s.isNotEmpty) {
      final match = escapeCodeReAnywhere.firstMatch(s);
      final beforeMatch = s.substring(0, match?.start);
      if (match != null) {
        tryProcessKeyCode(match[0]!);
        s = s.substring(match.end);
      } else {
        s = "";
      }
      if (csiRe.hasMatch(beforeMatch)) {
        unhandledListener?.call(beforeMatch);
        continue;
      }
      for (final char in Characters(beforeMatch)) {
        if (!tryProcessKeyCode(char)) {
          if (char.length == 1) {
            final codeUnit = char.codeUnit;
            if ((codeUnit >= 0x00 && codeUnit <= 0x1F) || // C0
                (codeUnit >= 0x80 && codeUnit <= 0x9F) || // C1
                codeUnit == 0x7F) {
              // DELETE
              unhandledListener?.call(char);
              // continue; TODO: why continue here?
            }
          }
          charListener?.call(char);
          handledStringListener?.call(char);
        }
      }
    }
  }

  bool tryProcessKeyCode(String s) {
    Key? key;
    Match? match;
    bool meta = false, shift = false, ctrl = false;
    if (s == '\r') {
      // carriage return
      key = Key.carriageReturn;
    } else if (s == '\n') {
      // enter, should have been called linefeed
      key = Key.enter;
      // linefeed
      // key = Key.linefeed;
    } else if (s == '\t') {
      // tab
      key = Key.tab;
    } else if (s == '\b' || s == '\x7f' || s == '\x1b\x7f' || s == '\x1b\b') {
      // backspace or ctrl+h
      key = Key.backspace;
      meta = (s.codeUnitAt(0) == 0x1b);
    } else if (s == '\x1b' || s == '\x1b\x1b') {
      // escape key
      key = Key.escape;
      meta = (s.length == 2);
    } else if (s == ' ' || s == '\x1b ') {
      key = Key.space;
      meta = (s.length == 2);
    } else if (s.length == 1 && s.codeUnit <= 0x1a) {
      // ctrl+letter
      if (s.codeUnit == 0) {
        key = Key.space;
      } else {
        key = Key.letter(s.codeUnit - 1);
      }
      ctrl = true;
    } else if (s.length == 1 && s.codeUnit >= 28 && s.codeUnit <= 31) {
      // ctrl+/,],^
      key = switch (s.codeUnit) {
        28 => Key.backslash,
        29 => Key.brace_right,
        30 => Key.caret,
        _ => Key.underscore,
      };
      ctrl = true;
    } else if (s.length == 2 &&
        s.codeUnitAt(0) == 0x1b &&
        s.codeUnitAt(1) <= 0x1a) {
      // meta+ctrl+letter
      if (s.codeUnitAt(1) == 0) {
        key = Key.space;
      } else {
        key = Key.letter(s.codeUnitAt(1) - 1);
      }
      ctrl = true;
      meta = true;
      if(key == Key.m) {
        key = Key.enter;
        ctrl = false;
      }
    } else if (s.length == 2 &&
        s.codeUnitAt(0) == 0x1b &&
        s.codeUnitAt(1) >= 28 &&
        s.codeUnitAt(1) <= 31) {
      // meta+ctrl+/,],^
      key = switch (s.codeUnitAt(1)) {
        28 => Key.backslash,
        29 => Key.brace_right,
        30 => Key.caret,
        _ => Key.underscore,
      };
      ctrl = true;
      meta = true;
    } else if (s.length == 1 && s.codeUnit >= _0 && s.codeUnit <= _9) {
      // number (0-9)
      key = Key.digit(s.codeUnit - _0);
    } else if (s.length == 1 && s.codeUnit >= _a && s.codeUnit <= _z) {
      // lowercase letter (a-z)
      key = Key.letter(s.codeUnit - _a);
    } else if (s.length == 1 &&
        ((s.codeUnit >= 33 && s.codeUnit <= 47) ||
            (s.codeUnit >= 58 && s.codeUnit <= 64) ||
            (s.codeUnit >= 91 && s.codeUnit <= 96) ||
            (s.codeUnit >= 123 && s.codeUnit <= 126))) {
      // punctuation (except whitespace)
      key = Key.tryGetAsciiKey(s.codeUnit)!;
    } else if (s.length == 1 && s.codeUnit >= _A && s.codeUnit <= _Z) {
      // shift+letter (A-Z)
      key = Key.letter(s.codeUnit - _A);
      shift = true;
    } else if (s.length == 2 &&
        s.codeUnitAt(0) == 0x1b &&
        ((s.codeUnitAt(1) >= 32 && s.codeUnitAt(1) <= 126) ||
            s.codeUnitAt(1) == 9)) {
      // meta+character key
      key = Key.tryGetAsciiKey(s.toLowerCase().codeUnitAt(1))!;
      meta = true;
      shift = RegExp(r'^[A-Z]$').hasMatch(s.substring(1));
    } else if ((match = functionKeyCodeRe.matchAsPrefix(s)) != null) {
      // ansi escape sequence
      // TODO: add keypad keys
      // TODO: and support for modifyKeyboard from xterm

      // reassemble the key code leaving out leading \x1b's,
      // the modifier key bitflag and any meaningless "1;" sequence
      final code =
          (match![1] ?? '') +
          (match[2] ?? '') +
          (match[4] ?? '') +
          (match[9] ?? '');
      int modifier =
          int.tryParse(match[3] ?? "") ?? int.tryParse(match[8] ?? "") ?? 1;
      modifier--;

      // Parse the key modifier
      ctrl = (modifier & 4) != 0;
      meta = (modifier & 10) != 0;
      shift = (modifier & 1) != 0;

      // Parse the key itself
      switch (code) {
        /* xterm/gnome ESC O letter */
        case 'OP':
        case '[P':
          key = Key.F1;
          break;
        case 'OQ':
        case '[Q':
          key = Key.F2;
          break;
        case 'OR':
        case '[R':
          key = Key.F3;
          break;
        case 'OS':
        case '[S':
          key = Key.F4;
          break;

        /* xterm/rxvt ESC [ number ~ */
        case '[11~':
          key = Key.F1;
          break;
        case '[12~':
          key = Key.F2;
          break;
        case '[13~':
          key = Key.F3;
          break;
        case '[14~':
          key = Key.F4;
          break;

        /* from Cygwin and used in libuv */
        case '[[A':
          key = Key.F1;
          break;
        case '[[B':
          key = Key.F2;
          break;
        case '[[C':
          key = Key.F3;
          break;
        case '[[D':
          key = Key.F4;
          break;
        case '[[E':
          key = Key.F5;
          break;

        /* common */
        case '[15~':
          key = Key.F5;
          break;
        case '[17~':
          key = Key.F6;
          break;
        case '[18~':
          key = Key.F7;
          break;
        case '[19~':
          key = Key.F8;
          break;
        case '[20~':
          key = Key.F9;
          break;
        case '[21~':
          key = Key.F10;
          break;
        case '[23~':
          key = Key.F11;
          break;
        case '[24~':
          key = Key.F12;
          break;

        /* xterm ESC [ letter */
        case '[A':
          key = Key.arrowUp;
          break;
        case '[B':
          key = Key.arrowDown;
          break;
        case '[C':
          key = Key.arrowRight;
          break;
        case '[D':
          key = Key.arrowLeft;
          break;
        case '[E':
          key = Key.clear;
          break;
        case '[F':
          key = Key.end;
          break;
        case '[H':
          key = Key.home;
          break;

        /* xterm/gnome ESC O letter */
        case 'OA':
          key = Key.arrowUp;
          break;
        case 'OB':
          key = Key.arrowDown;
          break;
        case 'OC':
          key = Key.arrowRight;
          break;
        case 'OD':
          key = Key.arrowLeft;
          break;
        case 'OE':
          key = Key.clear;
          break;
        case 'OF':
          key = Key.end;
          break;
        case 'OH':
          key = Key.home;
          break;

        /* xterm/rxvt ESC [ number ~ */
        case '[1~':
          key = Key.home;
          break;
        case '[2~':
          key = Key.insert;
          break;
        case '[3~':
          key = Key.delete;
          break;
        case '[4~':
          key = Key.end;
          break;
        case '[5~':
          key = Key.pageUp;
          break;
        case '[6~':
          key = Key.pageDown;
          break;

        /* putty */
        case '[[5~':
          key = Key.pageUp;
          break;
        case '[[6~':
          key = Key.pageDown;
          break;

        /* rxvt */
        case '[7~':
          key = Key.home;
          break;
        case '[8~':
          key = Key.end;
          break;

        /* rxvt keys with modifiers */
        case '[a':
          key = Key.arrowUp;
          shift = true;
          break;
        case '[b':
          key = Key.arrowDown;
          shift = true;
          break;
        case '[c':
          key = Key.arrowRight;
          shift = true;
          break;
        case '[d':
          key = Key.arrowLeft;
          shift = true;
          break;
        case '[e':
          key = Key.clear;
          shift = true;
          break;

        case r'[2$':
          key = Key.insert;
          shift = true;
          break;
        case r'[3$':
          key = Key.delete;
          shift = true;
          break;
        case r'[5$':
          key = Key.pageUp;
          shift = true;
          break;
        case r'[6$':
          key = Key.pageDown;
          shift = true;
          break;
        case r'[7$':
          key = Key.home;
          shift = true;
          break;
        case r'[8$':
          key = Key.end;
          shift = true;
          break;

        case 'Oa':
          key = Key.arrowUp;
          ctrl = true;
          break;
        case 'Ob':
          key = Key.arrowDown;
          ctrl = true;
          break;
        case 'Oc':
          key = Key.arrowRight;
          ctrl = true;
          break;
        case 'Od':
          key = Key.arrowLeft;
          ctrl = true;
          break;
        case 'Oe':
          key = Key.clear;
          ctrl = true;
          break;

        case '[2^':
          key = Key.insert;
          ctrl = true;
          break;
        case '[3^':
          key = Key.delete;
          ctrl = true;
          break;
        case '[5^':
          key = Key.pageUp;
          ctrl = true;
          break;
        case '[6^':
          key = Key.pageDown;
          ctrl = true;
          break;
        case '[7^':
          key = Key.home;
          ctrl = true;
          break;
        case '[8^':
          key = Key.end;
          ctrl = true;
          break;

        /* misc. */
        case '[Z':
          key = Key.tab;
          shift = true;
          break;
      }
    }
    if (key != null) {
      final stroke = KeyStroke(
        key,
        isShiftPressed: shift,
        isCtrlPressed: ctrl,
        isMetaPressed: meta,
      );
      keyStrokeListener?.call(stroke);
      handledStringListener?.call(s);
      return true;
    }
    unhandledListener?.call(s);
    return false;
  }
}
