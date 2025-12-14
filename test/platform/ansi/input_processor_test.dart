import 'dart:async';

import 'package:dart_terminal/src/platform/ansi/input_processor.dart';
import 'package:test/test.dart';

import '../../util.dart';

void main() {
  print("obj");
  late InputProcessor inputProcessor;
  late StreamController<List<int>> inputController;
  late StreamController<dynamic> outputController;
  late Stream<dynamic> output;

  void add(String input) {
    // inputProcessor.processInput(input.codeUnits);
    inputController.add(input.codeUnits);
  }

  setUp(() {
    outputController = StreamController<dynamic>();
    output = outputController.stream;
    inputController = StreamController<List<int>>();

    inputProcessor =
        InputProcessor(
            bracketedPasteTimeoutDuration: Duration(milliseconds: 10),
          )
          ..pasteListener = ((s) => outputController.add((s, "paste")))
          ..charListener = ((s) => outputController.add((s, "char")))
          ..mouseListener = outputController.add
          ..keyStrokeListener = ((s) {
            print(s);
            outputController.add(s);
          })
          ..focusListener = outputController.add
          ..cursorPositionQueryListener = outputController.add
          ..unhandledListener = ((s) => outputController.add((s, "error")))
          ..deviceAttributesListener = outputController.add;
    inputProcessor.startListening(inputController.stream);
  });

  tearDown(() async {
    await inputProcessor.stopListening();
    await outputController.close();
  });

  group('bracketed paste', () {
    const beginCode = "\x1b[200~";
    const endCode = "\x1b[201~";
    test('Bracketed paste timeout', () async {
      add(beginCode + "start");

      Future<void>.delayed(Duration(milliseconds: 5), () async {
        add("second");
      });

      Future<void>.delayed(Duration(milliseconds: 20), () async {
        add("end" + endCode);
      });

      await expectEmitsExactlyWithin(output, [
        ("start" + "second", "paste"),
        ("\x1b[201~", "error"),
        KeyStrokes.e,
        KeyStrokes.n,
        KeyStrokes.d,
      ]);

      await Future<void>.delayed(Duration(milliseconds: 60));
    });

    test('Bracketed paste success split up 1', () async {
      add(beginCode + "start");

      Future<void>.delayed(Duration(milliseconds: 5), () async {
        add("second");
      });

      Future<void>.delayed(Duration(milliseconds: 5), () async {
        add("end" + endCode);
      });

      await expectEmitsExactlyWithin(output, [
        ("start" + "second" + "end", "paste"),
      ]);

      await Future<void>.delayed(Duration(milliseconds: 60));
    });

    test('Bracketed paste success split up 2', () async {
      add(beginCode + "start");

      Future<void>.delayed(Duration(milliseconds: 5), () async {
        add("second" + "end" + endCode);
      });

      await expectEmitsExactlyWithin(output, [
        ("start" + "second" + "end", "paste"),
      ]);

      await Future<void>.delayed(Duration(milliseconds: 60));
    });

    test('Bracketed paste success split up 3', () async {
      add(beginCode);

      Future<void>.delayed(Duration(milliseconds: 9), () async {
        add("start");
      });

      Future<void>.delayed(Duration(milliseconds: 9), () async {
        add("second");
      });

      Future<void>.delayed(Duration(milliseconds: 9), () async {
        add("end" + endCode);
      });

      await expectEmitsExactlyWithin(output, [
        ("start" + "second" + "end", "paste"),
      ]);

      await Future<void>.delayed(Duration(milliseconds: 60));
    });

    test('Bracketed paste success single buffer', () async {
      add(beginCode + "content" + endCode);

      await expectEmitsExactlyWithin(output, [("content", "paste")]);

      await Future<void>.delayed(Duration(milliseconds: 60));
    });
  });

  test("focus events", () async {
    add("\x1b[I");
    add("\x1b[O");
    add("\x1b[M#!!" + "\x1b[O" + "\x1b[M#!!"); // + mouse events

    await expectEmitsExactlyWithin(output, [true, false, false]);

    await Future<void>.delayed(Duration(milliseconds: 60));
  });

  test("cursor position request", () async {
    final y = 10, x = 12;
    inputProcessor.awaitingCursorPositionAnswer = true;

    add("\x1B[${y + 1};${x + 1}R");

    await expectEmitsExactlyWithin(output, [Position(x, y)]);

    await Future<void>.delayed(Duration(milliseconds: 60));
  });

  test("handle multiple in same buffer", () async {
    add("\x1b[M#!!" + "\x1b[M !!"); // left button press

    await expectEmitsExactlyWithin(output, [
      MouseMotionEvent.hover(zero),
      MousePressEvent(zero, MouseButton.left, MouseButtonState.pressed),
    ]);

    await Future<void>.delayed(Duration(milliseconds: 60));
  });

  test("x10 mouse events", () async {
    add("\x1b[M !!"); // left button press
    add("\x1b[M#!!"); // left button release
    add("\x1b[Ma!!"); // scroll down
    add("\x1b[M`!!"); // scroll up
    add("\x1b[M#!!"); // hover

    await expectEmitsExactlyWithin(output, [
      MousePressEvent(zero, MouseButton.left, MouseButtonState.pressed),
      MousePressEvent(zero, MouseButton.left, MouseButtonState.released),
      MouseScrollEvent(zero, e2),
      MouseScrollEvent(zero, -e2),
      MouseMotionEvent.hover(zero),
    ]);

    await Future<void>.delayed(Duration(milliseconds: 60));
  });

  test("basic xterm mouse events", () async {
    add("\x1b[M !!"); // left button press
    add("\x1b[M#!!"); // left button release
    add("\x1b[Ma!!"); // scroll down
    add("\x1b[M`!!"); // scroll up
    add("\x1b[M#!!"); // hover

    await expectEmitsExactlyWithin(output, [
      MousePressEvent(zero, MouseButton.left, MouseButtonState.pressed),
      MousePressEvent(zero, MouseButton.left, MouseButtonState.released),
      MouseScrollEvent(zero, e2),
      MouseScrollEvent(zero, -e2),
      MouseMotionEvent.hover(zero),
    ]);

    await Future<void>.delayed(Duration(milliseconds: 60));
  });

  test("basic xterm mouse events high values + uft8 (DECSET 1005)", () async {
    add("\x1b[M \xFF\xFF"); // left button press (x=y=222)
    add("\x1b[M \xFE\xFE"); // left button press (x=y=221)
    add("\x1b[M !" + String.fromCharCode(1000)); // (x=0,y=999-32)
    add("\x1b[M " + String.fromCharCode(1000) + "!"); // (x=999-32,y=0)

    await expectEmitsExactlyWithin(output, [
      MousePressEvent(
        Position(222, 222),
        MouseButton.left,
        MouseButtonState.pressed,
      ),
      MousePressEvent(
        Position(221, 221),
        MouseButton.left,
        MouseButtonState.pressed,
      ),
      MousePressEvent(
        Position(0, 999 - 32),
        MouseButton.left,
        MouseButtonState.pressed,
      ),
      MousePressEvent(
        Position(999 - 32, 0),
        MouseButton.left,
        MouseButtonState.pressed,
      ),
    ]);

    await Future<void>.delayed(Duration(milliseconds: 60));
  });

  test("xterm SGR mouse events", () async {
    add("\x1b[<0;1;1M"); // press left
    add("\x1b[<0;1;1m"); // release left
    add("\x1b[<2;1;1M"); // press right
    add("\x1b[<2;1;1m"); // release right
    add("\x1b[<65;1;1M"); // scroll down
    add("\x1b[<64;1;1M"); // scroll up
    add("\x1b[<66;1;1M"); // scroll right
    add("\x1b[<67;1;1M"); // scroll left
    add("\x1b[<35;1;1M"); // hover
    add("\x1b[<32;1;1M"); // right press motion
    add("\x1b[<34;1;1M"); // left press motion

    await expectEmitsExactlyWithin(output, [
      MousePressEvent(zero, MouseButton.left, MouseButtonState.pressed),
      MousePressEvent(zero, MouseButton.left, MouseButtonState.released),
      MousePressEvent(zero, MouseButton.right, MouseButtonState.pressed),
      MousePressEvent(zero, MouseButton.right, MouseButtonState.released),
      MouseScrollEvent(zero, e2),
      MouseScrollEvent(zero, -e2),
      MouseScrollEvent(zero, e1),
      MouseScrollEvent(zero, -e1),
      MouseMotionEvent.hover(zero),
      MouseMotionEvent(zero, MouseButton.left),
      MouseMotionEvent(zero, MouseButton.right),
    ]);

    await Future<void>.delayed(Duration(milliseconds: 60));
  });

  test("basic keystrokes", () async {
    add("a"); // press left
    add("A"); // press left
    add("aaa"); // press left

    await expectEmitsExactlyWithin(output, [
      KeyStrokes.a,
      KeyStrokes.A,
      KeyStrokes.a,
      KeyStrokes.a,
      KeyStrokes.a,
    ]);

    await Future<void>.delayed(Duration(milliseconds: 60));
  });

  test("most ansi compabible keystroke", () async {
    // Raw input strings from terminal
    final List<String> terminalInputs = [
      // Basic lowercase letters
      'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm',
      'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z',

      // Basic uppercase letters (Shift held)
      'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
      'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',

      // Digits
      '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',

      // Punctuation
      '\r', '\n', '\t', '\x1b', ' ',
      ')', '!', '@', '#', '\$', '%', '^', '&', '*', '(',
      '_', '+', '{', '}', '|', ':', '"', '<', '>', '?', '~',
      '-', '=', '[', ']', '\\', ';', '\'', ',', '.', '/', '`',

      // Control characters
      '\x00', // Ctrl+@
      '\x01', // Ctrl+A
      '\x02', // Ctrl+B
      '\x03', // Ctrl+C
      '\x04', // Ctrl+D
      '\x05', // Ctrl+E
      '\x06', // Ctrl+F
      '\x07', // Ctrl+G
      '\x08', // Ctrl+H (Backspace)
      '\x09', // Ctrl+I (Tab)
      '\x0a', // Ctrl+J
      '\x0b', // Ctrl+K
      '\x0c', // Ctrl+L
      '\x0d', // Ctrl+M (Enter)
      '\x0e', // Ctrl+N
      '\x0f', // Ctrl+O
      '\x10', // Ctrl+P
      '\x11', // Ctrl+Q
      '\x12', // Ctrl+R
      '\x13', // Ctrl+S
      '\x14', // Ctrl+T
      '\x15', // Ctrl+U
      '\x16', // Ctrl+V
      '\x17', // Ctrl+W
      '\x18', // Ctrl+X
      '\x19', // Ctrl+Y
      '\x1a', // Ctrl+Z
      '\x1b', // Ctrl+[ (Escape)
      '\x1c', // Ctrl+\\
      '\x1d', // Ctrl+]
      '\x1e', // Ctrl+^
      '\x1f', // Ctrl+_
      '\x7f', // Delete/Backspace
      // Arrow keys
      '\x1b[A', // Up
      '\x1b[B', // Down
      '\x1b[C', // Right
      '\x1b[D', // Left
      // Arrow keys with Shift
      '\x1b[1;2A', // Shift+Up
      '\x1b[1;2B', // Shift+Down
      '\x1b[1;2C', // Shift+Right
      '\x1b[1;2D', // Shift+Left
      // Arrow keys with Alt
      '\x1b[1;3A', // Alt+Up
      '\x1b[1;3B', // Alt+Down
      '\x1b[1;3C', // Alt+Right
      '\x1b[1;3D', // Alt+Left
      // Arrow keys with Alt+Shift
      '\x1b[1;4A', // Alt+Shift+Up
      '\x1b[1;4B', // Alt+Shift+Down
      '\x1b[1;4C', // Alt+Shift+Right
      '\x1b[1;4D', // Alt+Shift+Left
      // Arrow keys with Ctrl
      '\x1b[1;5A', // Ctrl+Up
      '\x1b[1;5B', // Ctrl+Down
      '\x1b[1;5C', // Ctrl+Right
      '\x1b[1;5D', // Ctrl+Left
      // Arrow keys with Ctrl+Shift
      '\x1b[1;6A', // Ctrl+Shift+Up
      '\x1b[1;6B', // Ctrl+Shift+Down
      '\x1b[1;6C', // Ctrl+Shift+Right
      '\x1b[1;6D', // Ctrl+Shift+Left
      // Arrow keys with Ctrl+Alt
      '\x1b[1;7A', // Ctrl+Alt+Up
      '\x1b[1;7B', // Ctrl+Alt+Down
      '\x1b[1;7C', // Ctrl+Alt+Right
      '\x1b[1;7D', // Ctrl+Alt+Left
      // Arrow keys with Ctrl+Alt+Shift
      '\x1b[1;8A', // Ctrl+Alt+Shift+Up
      '\x1b[1;8B', // Ctrl+Alt+Shift+Down
      '\x1b[1;8C', // Ctrl+Alt+Shift+Right
      '\x1b[1;8D', // Ctrl+Alt+Shift+Left
      // Function keys F1-F12
      '\x1bOP', // F1
      '\x1bOQ', // F2
      '\x1bOR', // F3
      '\x1bOS', // F4
      '\x1b[15~', // F5
      '\x1b[17~', // F6
      '\x1b[18~', // F7
      '\x1b[19~', // F8
      '\x1b[20~', // F9
      '\x1b[21~', // F10
      '\x1b[23~', // F11
      '\x1b[24~', // F12
      // Function keys with Shift
      '\x1b[1;2P', // Shift+F1
      '\x1b[1;2Q', // Shift+F2
      '\x1b[1;2R', // Shift+F3
      '\x1b[1;2S', // Shift+F4
      '\x1b[15;2~', // Shift+F5
      '\x1b[17;2~', // Shift+F6
      '\x1b[18;2~', // Shift+F7
      '\x1b[19;2~', // Shift+F8
      '\x1b[20;2~', // Shift+F9
      '\x1b[21;2~', // Shift+F10
      '\x1b[23;2~', // Shift+F11
      '\x1b[24;2~', // Shift+F12
      // Function keys with Alt
      '\x1b[1;3P', // Alt+F1
      '\x1b[1;3Q', // Alt+F2
      '\x1b[1;3R', // Alt+F3
      '\x1b[1;3S', // Alt+F4
      '\x1b[15;3~', // Alt+F5
      '\x1b[17;3~', // Alt+F6
      '\x1b[18;3~', // Alt+F7
      '\x1b[19;3~', // Alt+F8
      '\x1b[20;3~', // Alt+F9
      '\x1b[21;3~', // Alt+F10
      '\x1b[23;3~', // Alt+F11
      '\x1b[24;3~', // Alt+F12
      // Function keys with Ctrl
      '\x1b[1;5P', // Ctrl+F1
      '\x1b[1;5Q', // Ctrl+F2
      '\x1b[1;5R', // Ctrl+F3
      '\x1b[1;5S', // Ctrl+F4
      '\x1b[15;5~', // Ctrl+F5
      '\x1b[17;5~', // Ctrl+F6
      '\x1b[18;5~', // Ctrl+F7
      '\x1b[19;5~', // Ctrl+F8
      '\x1b[20;5~', // Ctrl+F9
      '\x1b[21;5~', // Ctrl+F10
      '\x1b[23;5~', // Ctrl+F11
      '\x1b[24;5~', // Ctrl+F12
      // Navigation keys
      '\x1b[1~', // Home
      '\x1b[2~', // Insert
      '\x1b[3~', // Delete
      '\x1b[4~', // End
      '\x1b[5~', // Page Up
      '\x1b[6~', // Page Down
      // Navigation keys with Shift
      '\x1b[1;2H', // Shift+Home
      '\x1b[1;2F', // Shift+End
      '\x1b[2;2~', // Shift+Insert
      '\x1b[3;2~', // Shift+Delete
      '\x1b[5;2~', // Shift+Page Up
      '\x1b[6;2~', // Shift+Page Down
      // Navigation keys with Alt
      '\x1b[1;3H', // Alt+Home
      '\x1b[1;3F', // Alt+End
      '\x1b[2;3~', // Alt+Insert
      '\x1b[3;3~', // Alt+Delete
      '\x1b[5;3~', // Alt+Page Up
      '\x1b[6;3~', // Alt+Page Down
      // Navigation keys with Ctrl
      '\x1b[1;5H', // Ctrl+Home
      '\x1b[1;5F', // Ctrl+End
      '\x1b[2;5~', // Ctrl+Insert
      '\x1b[3;5~', // Ctrl+Delete
      '\x1b[5;5~', // Ctrl+Page Up
      '\x1b[6;5~', // Ctrl+Page Down
      // Navigation keys with Ctrl+Shift
      '\x1b[1;6H', // Ctrl+Shift+Home
      '\x1b[1;6F', // Ctrl+Shift+End
      '\x1b[2;6~', // Ctrl+Shift+Insert
      '\x1b[3;6~', // Ctrl+Shift+Delete
      '\x1b[5;6~', // Ctrl+Shift+Page Up
      '\x1b[6;6~', // Ctrl+Shift+Page Down
      // Alt + letter combinations
      '\x1ba', '\x1bb', '\x1bc', '\x1bd', '\x1be', '\x1bf', '\x1bg', '\x1bh',
      '\x1bi', '\x1bj', '\x1bk', '\x1bl', '\x1bm', '\x1bn', '\x1bo', '\x1bp',
      '\x1bq', '\x1br', '\x1bs', '\x1bt', '\x1bu', '\x1bv', '\x1bw', '\x1bx',
      '\x1by', '\x1bz',

      // Alt + number combinations
      '\x1b0', '\x1b1', '\x1b2', '\x1b3', '\x1b4',
      '\x1b5', '\x1b6', '\x1b7', '\x1b8', '\x1b9',

      // Ctrl + Alt combinations
      '\x1b\x01', // Ctrl+Alt+A
      '\x1b\x02', // Ctrl+Alt+B
      '\x1b\x03', // Ctrl+Alt+C
      '\x1b\x04', // Ctrl+Alt+D
      '\x1b\x05', // Ctrl+Alt+E
      '\x1b\x06', // Ctrl+Alt+F
      '\x1b\x07', // Ctrl+Alt+G
      '\x1b\x08', // Ctrl+Alt+H
      '\x1b\x09', // Ctrl+Alt+I
      '\x1b\x0a', // Ctrl+Alt+J (Alt + Backspace)
      '\x1b\x0b', // Ctrl+Alt+K
      '\x1b\x0c', // Ctrl+Alt+L
      '\x1b\x0d', // Ctrl+Alt+M (Alt Enter)
      '\x1b\x0e', // Ctrl+Alt+N
      '\x1b\x0f', // Ctrl+Alt+O
      '\x1b\x10', // Ctrl+Alt+P
      '\x1b\x11', // Ctrl+Alt+Q
      '\x1b\x12', // Ctrl+Alt+R
      '\x1b\x13', // Ctrl+Alt+S
      '\x1b\x14', // Ctrl+Alt+T
      '\x1b\x15', // Ctrl+Alt+U
      '\x1b\x16', // Ctrl+Alt+V
      '\x1b\x17', // Ctrl+Alt+W
      '\x1b\x18', // Ctrl+Alt+X
      '\x1b\x19', // Ctrl+Alt+Y
      '\x1b\x1a', // Ctrl+Alt+Z
      // Backspace
      '\b', '\x7f', '\x1b\x7f', '\x1b\b',

      // Special combinations
      '\x1b[Z', // Shift+Tab
      '\x1b\x0d', // Alt+Enter
      '\x1b\x7f', // Alt+Backspace
      '\x1b\x1b', // Alt+Escape
      '\x00', // Ctrl+Space
      '\x1b ', // Alt+Space
    ];

    // Corresponding KeyStroke objects (same order as terminalInputs)
    final List<KeyStroke> keyStrokes = [
      // Basic lowercase letters
      KeyStroke(Key.a), KeyStroke(Key.b), KeyStroke(Key.c), KeyStroke(Key.d),
      KeyStroke(Key.e), KeyStroke(Key.f), KeyStroke(Key.g), KeyStroke(Key.h),
      KeyStroke(Key.i), KeyStroke(Key.j), KeyStroke(Key.k), KeyStroke(Key.l),
      KeyStroke(Key.m), KeyStroke(Key.n), KeyStroke(Key.o), KeyStroke(Key.p),
      KeyStroke(Key.q), KeyStroke(Key.r), KeyStroke(Key.s), KeyStroke(Key.t),
      KeyStroke(Key.u), KeyStroke(Key.v), KeyStroke(Key.w), KeyStroke(Key.x),
      KeyStroke(Key.y), KeyStroke(Key.z),

      // Basic uppercase letters (Shift held)
      KeyStroke(Key.a, isShiftPressed: true),
      KeyStroke(Key.b, isShiftPressed: true),
      KeyStroke(Key.c, isShiftPressed: true),
      KeyStroke(Key.d, isShiftPressed: true),
      KeyStroke(Key.e, isShiftPressed: true),
      KeyStroke(Key.f, isShiftPressed: true),
      KeyStroke(Key.g, isShiftPressed: true),
      KeyStroke(Key.h, isShiftPressed: true),
      KeyStroke(Key.i, isShiftPressed: true),
      KeyStroke(Key.j, isShiftPressed: true),
      KeyStroke(Key.k, isShiftPressed: true),
      KeyStroke(Key.l, isShiftPressed: true),
      KeyStroke(Key.m, isShiftPressed: true),
      KeyStroke(Key.n, isShiftPressed: true),
      KeyStroke(Key.o, isShiftPressed: true),
      KeyStroke(Key.p, isShiftPressed: true),
      KeyStroke(Key.q, isShiftPressed: true),
      KeyStroke(Key.r, isShiftPressed: true),
      KeyStroke(Key.s, isShiftPressed: true),
      KeyStroke(Key.t, isShiftPressed: true),
      KeyStroke(Key.u, isShiftPressed: true),
      KeyStroke(Key.v, isShiftPressed: true),
      KeyStroke(Key.w, isShiftPressed: true),
      KeyStroke(Key.x, isShiftPressed: true),
      KeyStroke(Key.y, isShiftPressed: true),
      KeyStroke(Key.z, isShiftPressed: true),

      // Digits
      KeyStroke(Key.digit_0), KeyStroke(Key.digit_1), KeyStroke(Key.digit_2),
      KeyStroke(Key.digit_3), KeyStroke(Key.digit_4), KeyStroke(Key.digit_5),
      KeyStroke(Key.digit_6), KeyStroke(Key.digit_7), KeyStroke(Key.digit_8),
      KeyStroke(Key.digit_9),

      // Punctuaction
      KeyStroke(Key.carriageReturn), // carriage return
      KeyStroke(Key.enter), // enter
      KeyStroke(Key.tab), // tab
      KeyStroke(Key.escape), // escape
      KeyStroke(Key.space), // space
      KeyStroke(Key.paren_right), // )
      KeyStroke(Key.exclamation), // !
      KeyStroke(Key.at), // @
      KeyStroke(Key.hash), // #
      KeyStroke(Key.dollar), // $
      KeyStroke(Key.percent), // %
      KeyStroke(Key.caret), // ^
      KeyStroke(Key.ampersand), // &
      KeyStroke(Key.asterisk), // *
      KeyStroke(Key.paren_left), // (
      KeyStroke(Key.underscore), // _ (underscore)
      KeyStroke(Key.plus), // + (plus)
      KeyStroke(Key.brace_left), // { (left brace)
      KeyStroke(Key.brace_right), // } (right brace)
      KeyStroke(Key.pipe), // | (pipe)
      KeyStroke(Key.colon), // : (colon)
      KeyStroke(Key.quote), // " (quote)
      KeyStroke(Key.less_than), // < (less than)
      KeyStroke(Key.greater_than), // > (greater than)
      KeyStroke(Key.question), // ? (question)
      KeyStroke(Key.tilde), // ~ (tilde)
      // Unshifted symbols - also not in Key enum
      KeyStroke(Key.minus), // - (minus)
      KeyStroke(Key.equals), // = (equals)
      KeyStroke(Key.bracket_left), // [ (left bracket)
      KeyStroke(Key.bracket_right), // ] (right bracket)
      KeyStroke(Key.backslash), // \ (backslash)
      KeyStroke(Key.semicolon), // ; (semicolon)
      KeyStroke(Key.apostrophe), // ' (apostrophe)
      KeyStroke(Key.comma), // , (comma)
      KeyStroke(Key.dot), // . (dot)
      KeyStroke(Key.slash), // / (slash)
      KeyStroke(Key.backtick), // ` (backtick)
      // Control characters
      KeyStroke(Key.space, isCtrlPressed: true), // Ctrl+@
      KeyStroke(Key.a, isCtrlPressed: true), // Ctrl+A
      KeyStroke(Key.b, isCtrlPressed: true), // Ctrl+B
      KeyStroke(Key.c, isCtrlPressed: true), // Ctrl+C
      KeyStroke(Key.d, isCtrlPressed: true), // Ctrl+D
      KeyStroke(Key.e, isCtrlPressed: true), // Ctrl+E
      KeyStroke(Key.f, isCtrlPressed: true), // Ctrl+F
      KeyStroke(Key.g, isCtrlPressed: true), // Ctrl+G
      KeyStroke(Key.backspace), // Ctrl+H  (Backspace)
      KeyStroke(Key.tab), // Ctrl+I (Tab)
      KeyStroke(Key.enter), // Ctrl+J (Enter)
      KeyStroke(Key.k, isCtrlPressed: true), // Ctrl+K
      KeyStroke(Key.l, isCtrlPressed: true), // Ctrl+L
      KeyStroke(Key.carriageReturn), // Ctrl+M (Enter)
      KeyStroke(Key.n, isCtrlPressed: true), // Ctrl+N
      KeyStroke(Key.o, isCtrlPressed: true), // Ctrl+O
      KeyStroke(Key.p, isCtrlPressed: true), // Ctrl+P
      KeyStroke(Key.q, isCtrlPressed: true), // Ctrl+Q
      KeyStroke(Key.r, isCtrlPressed: true), // Ctrl+R
      KeyStroke(Key.s, isCtrlPressed: true), // Ctrl+S
      KeyStroke(Key.t, isCtrlPressed: true), // Ctrl+T
      KeyStroke(Key.u, isCtrlPressed: true), // Ctrl+U
      KeyStroke(Key.v, isCtrlPressed: true), // Ctrl+V
      KeyStroke(Key.w, isCtrlPressed: true), // Ctrl+W
      KeyStroke(Key.x, isCtrlPressed: true), // Ctrl+X
      KeyStroke(Key.y, isCtrlPressed: true), // Ctrl+Y
      KeyStroke(Key.z, isCtrlPressed: true), // Ctrl+Z
      KeyStroke(Key.escape), // Ctrl+[ (Escape)
      KeyStroke(Key.backslash, isCtrlPressed: true), // Ctrl+\
      KeyStroke(Key.brace_right, isCtrlPressed: true), // Ctrl+]
      KeyStroke(Key.caret, isCtrlPressed: true), // Ctrl+^
      KeyStroke(Key.underscore, isCtrlPressed: true), // Ctrl+_
      KeyStroke(Key.backspace), // Delete/Backspace
      // Arrow keys
      KeyStroke(Key.arrowUp),
      KeyStroke(Key.arrowDown),
      KeyStroke(Key.arrowRight),
      KeyStroke(Key.arrowLeft),

      // Arrow keys with Shift
      KeyStroke(Key.arrowUp, isShiftPressed: true),
      KeyStroke(Key.arrowDown, isShiftPressed: true),
      KeyStroke(Key.arrowRight, isShiftPressed: true),
      KeyStroke(Key.arrowLeft, isShiftPressed: true),

      // Arrow keys with Alt
      KeyStroke(Key.arrowUp, isMetaPressed: true),
      KeyStroke(Key.arrowDown, isMetaPressed: true),
      KeyStroke(Key.arrowRight, isMetaPressed: true),
      KeyStroke(Key.arrowLeft, isMetaPressed: true),

      // Arrow keys with Alt+Shift
      KeyStroke(Key.arrowUp, isShiftPressed: true, isMetaPressed: true),
      KeyStroke(Key.arrowDown, isShiftPressed: true, isMetaPressed: true),
      KeyStroke(Key.arrowRight, isShiftPressed: true, isMetaPressed: true),
      KeyStroke(Key.arrowLeft, isShiftPressed: true, isMetaPressed: true),

      // Arrow keys with Ctrl
      KeyStroke(Key.arrowUp, isCtrlPressed: true),
      KeyStroke(Key.arrowDown, isCtrlPressed: true),
      KeyStroke(Key.arrowRight, isCtrlPressed: true),
      KeyStroke(Key.arrowLeft, isCtrlPressed: true),

      // Arrow keys with Ctrl+Shift
      KeyStroke(Key.arrowUp, isShiftPressed: true, isCtrlPressed: true),
      KeyStroke(Key.arrowDown, isShiftPressed: true, isCtrlPressed: true),
      KeyStroke(Key.arrowRight, isShiftPressed: true, isCtrlPressed: true),
      KeyStroke(Key.arrowLeft, isShiftPressed: true, isCtrlPressed: true),

      // Arrow keys with Ctrl+Alt
      KeyStroke(Key.arrowUp, isMetaPressed: true, isCtrlPressed: true),
      KeyStroke(Key.arrowDown, isMetaPressed: true, isCtrlPressed: true),
      KeyStroke(Key.arrowRight, isMetaPressed: true, isCtrlPressed: true),
      KeyStroke(Key.arrowLeft, isMetaPressed: true, isCtrlPressed: true),

      // Arrow keys with Ctrl+Alt+Shift
      KeyStroke(
        Key.arrowUp,
        isShiftPressed: true,
        isMetaPressed: true,
        isCtrlPressed: true,
      ),
      KeyStroke(
        Key.arrowDown,
        isShiftPressed: true,
        isMetaPressed: true,
        isCtrlPressed: true,
      ),
      KeyStroke(
        Key.arrowRight,
        isShiftPressed: true,
        isMetaPressed: true,
        isCtrlPressed: true,
      ),
      KeyStroke(
        Key.arrowLeft,
        isShiftPressed: true,
        isMetaPressed: true,
        isCtrlPressed: true,
      ),

      // Function keys F1-F12
      KeyStroke(Key.F1),
      KeyStroke(Key.F2),
      KeyStroke(Key.F3),
      KeyStroke(Key.F4),
      KeyStroke(Key.F5),
      KeyStroke(Key.F6),
      KeyStroke(Key.F7),
      KeyStroke(Key.F8),
      KeyStroke(Key.F9),
      KeyStroke(Key.F10),
      KeyStroke(Key.F11),
      KeyStroke(Key.F12),

      // Function keys with Shift
      KeyStroke(Key.F1, isShiftPressed: true),
      KeyStroke(Key.F2, isShiftPressed: true),
      KeyStroke(Key.F3, isShiftPressed: true),
      KeyStroke(Key.F4, isShiftPressed: true),
      KeyStroke(Key.F5, isShiftPressed: true),
      KeyStroke(Key.F6, isShiftPressed: true),
      KeyStroke(Key.F7, isShiftPressed: true),
      KeyStroke(Key.F8, isShiftPressed: true),
      KeyStroke(Key.F9, isShiftPressed: true),
      KeyStroke(Key.F10, isShiftPressed: true),
      KeyStroke(Key.F11, isShiftPressed: true),
      KeyStroke(Key.F12, isShiftPressed: true),

      // Function keys with Alt
      KeyStroke(Key.F1, isMetaPressed: true),
      KeyStroke(Key.F2, isMetaPressed: true),
      KeyStroke(Key.F3, isMetaPressed: true),
      KeyStroke(Key.F4, isMetaPressed: true),
      KeyStroke(Key.F5, isMetaPressed: true),
      KeyStroke(Key.F6, isMetaPressed: true),
      KeyStroke(Key.F7, isMetaPressed: true),
      KeyStroke(Key.F8, isMetaPressed: true),
      KeyStroke(Key.F9, isMetaPressed: true),
      KeyStroke(Key.F10, isMetaPressed: true),
      KeyStroke(Key.F11, isMetaPressed: true),
      KeyStroke(Key.F12, isMetaPressed: true),

      // Function keys with Ctrl
      KeyStroke(Key.F1, isCtrlPressed: true),
      KeyStroke(Key.F2, isCtrlPressed: true),
      KeyStroke(Key.F3, isCtrlPressed: true),
      KeyStroke(Key.F4, isCtrlPressed: true),
      KeyStroke(Key.F5, isCtrlPressed: true),
      KeyStroke(Key.F6, isCtrlPressed: true),
      KeyStroke(Key.F7, isCtrlPressed: true),
      KeyStroke(Key.F8, isCtrlPressed: true),
      KeyStroke(Key.F9, isCtrlPressed: true),
      KeyStroke(Key.F10, isCtrlPressed: true),
      KeyStroke(Key.F11, isCtrlPressed: true),
      KeyStroke(Key.F12, isCtrlPressed: true),

      // Navigation keys
      KeyStroke(Key.home),
      KeyStroke(Key.insert),
      KeyStroke(Key.delete),
      KeyStroke(Key.end),
      KeyStroke(Key.pageUp),
      KeyStroke(Key.pageDown),

      // Navigation keys with Shift
      KeyStroke(Key.home, isShiftPressed: true),
      KeyStroke(Key.end, isShiftPressed: true),
      KeyStroke(Key.insert, isShiftPressed: true),
      KeyStroke(Key.delete, isShiftPressed: true),
      KeyStroke(Key.pageUp, isShiftPressed: true),
      KeyStroke(Key.pageDown, isShiftPressed: true),

      // Navigation keys with Alt
      KeyStroke(Key.home, isMetaPressed: true),
      KeyStroke(Key.end, isMetaPressed: true),
      KeyStroke(Key.insert, isMetaPressed: true),
      KeyStroke(Key.delete, isMetaPressed: true),
      KeyStroke(Key.pageUp, isMetaPressed: true),
      KeyStroke(Key.pageDown, isMetaPressed: true),

      // Navigation keys with Ctrl
      KeyStroke(Key.home, isCtrlPressed: true),
      KeyStroke(Key.end, isCtrlPressed: true),
      KeyStroke(Key.insert, isCtrlPressed: true),
      KeyStroke(Key.delete, isCtrlPressed: true),
      KeyStroke(Key.pageUp, isCtrlPressed: true),
      KeyStroke(Key.pageDown, isCtrlPressed: true),

      // Navigation keys with Ctrl+Shift
      KeyStroke(Key.home, isShiftPressed: true, isCtrlPressed: true),
      KeyStroke(Key.end, isShiftPressed: true, isCtrlPressed: true),
      KeyStroke(Key.insert, isShiftPressed: true, isCtrlPressed: true),
      KeyStroke(Key.delete, isShiftPressed: true, isCtrlPressed: true),
      KeyStroke(Key.pageUp, isShiftPressed: true, isCtrlPressed: true),
      KeyStroke(Key.pageDown, isShiftPressed: true, isCtrlPressed: true),

      // Alt + letter combinations
      KeyStroke(Key.a, isMetaPressed: true),
      KeyStroke(Key.b, isMetaPressed: true),
      KeyStroke(Key.c, isMetaPressed: true),
      KeyStroke(Key.d, isMetaPressed: true),
      KeyStroke(Key.e, isMetaPressed: true),
      KeyStroke(Key.f, isMetaPressed: true),
      KeyStroke(Key.g, isMetaPressed: true),
      KeyStroke(Key.h, isMetaPressed: true),
      KeyStroke(Key.i, isMetaPressed: true),
      KeyStroke(Key.j, isMetaPressed: true),
      KeyStroke(Key.k, isMetaPressed: true),
      KeyStroke(Key.l, isMetaPressed: true),
      KeyStroke(Key.m, isMetaPressed: true),
      KeyStroke(Key.n, isMetaPressed: true),
      KeyStroke(Key.o, isMetaPressed: true),
      KeyStroke(Key.p, isMetaPressed: true),
      KeyStroke(Key.q, isMetaPressed: true),
      KeyStroke(Key.r, isMetaPressed: true),
      KeyStroke(Key.s, isMetaPressed: true),
      KeyStroke(Key.t, isMetaPressed: true),
      KeyStroke(Key.u, isMetaPressed: true),
      KeyStroke(Key.v, isMetaPressed: true),
      KeyStroke(Key.w, isMetaPressed: true),
      KeyStroke(Key.x, isMetaPressed: true),
      KeyStroke(Key.y, isMetaPressed: true),
      KeyStroke(Key.z, isMetaPressed: true),

      // Alt + number combinations
      KeyStroke(Key.digit_0, isMetaPressed: true),
      KeyStroke(Key.digit_1, isMetaPressed: true),
      KeyStroke(Key.digit_2, isMetaPressed: true),
      KeyStroke(Key.digit_3, isMetaPressed: true),
      KeyStroke(Key.digit_4, isMetaPressed: true),
      KeyStroke(Key.digit_5, isMetaPressed: true),
      KeyStroke(Key.digit_6, isMetaPressed: true),
      KeyStroke(Key.digit_7, isMetaPressed: true),
      KeyStroke(Key.digit_8, isMetaPressed: true),
      KeyStroke(Key.digit_9, isMetaPressed: true),

      // Ctrl + Alt combinations
      KeyStroke(Key.a, isMetaPressed: true, isCtrlPressed: true),
      KeyStroke(Key.b, isMetaPressed: true, isCtrlPressed: true),
      KeyStroke(Key.c, isMetaPressed: true, isCtrlPressed: true),
      KeyStroke(Key.d, isMetaPressed: true, isCtrlPressed: true),
      KeyStroke(Key.e, isMetaPressed: true, isCtrlPressed: true),
      KeyStroke(Key.f, isMetaPressed: true, isCtrlPressed: true),
      KeyStroke(Key.g, isMetaPressed: true, isCtrlPressed: true),
      KeyStroke(Key.backspace, isMetaPressed: true),
      KeyStroke(Key.i, isMetaPressed: true, isCtrlPressed: true),
      KeyStroke(Key.j, isMetaPressed: true, isCtrlPressed: true),
      KeyStroke(Key.k, isMetaPressed: true, isCtrlPressed: true),
      KeyStroke(Key.l, isMetaPressed: true, isCtrlPressed: true),
      KeyStroke(Key.enter, isMetaPressed: true),
      KeyStroke(Key.n, isMetaPressed: true, isCtrlPressed: true),
      KeyStroke(Key.o, isMetaPressed: true, isCtrlPressed: true),
      KeyStroke(Key.p, isMetaPressed: true, isCtrlPressed: true),
      KeyStroke(Key.q, isMetaPressed: true, isCtrlPressed: true),
      KeyStroke(Key.r, isMetaPressed: true, isCtrlPressed: true),
      KeyStroke(Key.s, isMetaPressed: true, isCtrlPressed: true),
      KeyStroke(Key.t, isMetaPressed: true, isCtrlPressed: true),
      KeyStroke(Key.u, isMetaPressed: true, isCtrlPressed: true),
      KeyStroke(Key.v, isMetaPressed: true, isCtrlPressed: true),
      KeyStroke(Key.w, isMetaPressed: true, isCtrlPressed: true),
      KeyStroke(Key.x, isMetaPressed: true, isCtrlPressed: true),
      KeyStroke(Key.y, isMetaPressed: true, isCtrlPressed: true),
      KeyStroke(Key.z, isMetaPressed: true, isCtrlPressed: true),

      // Backspace
      KeyStroke(Key.backspace),
      KeyStroke(Key.backspace),
      KeyStroke(Key.backspace, isMetaPressed: true),
      KeyStroke(Key.backspace, isMetaPressed: true),

      // Special combinations
      KeyStroke(Key.tab, isShiftPressed: true), // Shift+Tab
      KeyStroke(Key.enter, isMetaPressed: true), // Alt+Enter
      KeyStroke(Key.backspace, isMetaPressed: true), // Alt+Backspace
      KeyStroke(Key.escape, isMetaPressed: true), // Alt+Escape
      KeyStroke(Key.space, isCtrlPressed: true), // Ctrl+Space
      KeyStroke(Key.space, isMetaPressed: true), // Alt+Space
    ];
    for (int i = 0; i < terminalInputs.length; i++) {
      print('$i: "${terminalInputs[i]}" => ${keyStrokes[i]}');
    }
    terminalInputs.forEach(add);

    await expectEmitsExactlyWithin(output, keyStrokes);

    await Future<void>.delayed(Duration(milliseconds: 60));
  });
}
