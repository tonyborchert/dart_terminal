import 'package:dart_terminal/core.dart';

/// ANSI escape sequences and control codes for terminal manipulation.
///
/// This module provides constants and functions for generating ANSI escape sequences
/// that control terminal behavior, cursor movement, text formatting, and colors.
/// Based on documentation from:
/// - https://gist.github.com/ConnerWill/d4b6c776b509add763e17f9f113fd25b
/// - https://invisible-island.net/xterm/ctlseqs/ctlseqs.html
///

/// Annotation for defining that a escape code/control code is part of
/// ANSI X3.64 / ECMA-48, DEC and XTerm.
class _Ansi {
  const _Ansi();
}

/// If an escape code is part of DEC and XTerm but not ANSI.
class _DEC {
  const _DEC();
}

/// If an escape code is part of XTerm but not DEC (or ANSI).
class _Xterm {
  final bool alwaysSupported;
  const _Xterm({this.alwaysSupported = true});
}

//==============================================================================
// BASIC ASCII CONTROL CODES
//==============================================================================

/// Ring the terminal bell (audio or visual alert)
@_Ansi()
const String bell = '\x07';

/// Move cursor one position left
@_Ansi()
const String backspace = '\x08';

/// Move cursor to next tab stop
@_Ansi()
const String tab = '\x09';

/// Move cursor to beginning of next line
@_Ansi()
const String lineFeed = '\x0A';

/// Move cursor down one line maintaining column position
@_Ansi()
const String verticalTab = '\x0B';

/// Move cursor to next page (often treated like a newline)
@_Ansi()
const String formFeed = '\x0C';

/// Move cursor to beginning of current line
@_Ansi()
const String carriageReturn = '\x0D';

/// Start of escape sequence
@_Ansi()
const String escape = '\x1B';

/// Delete character at cursor
@_Ansi()
const String delete = '\x7F';

//==============================================================================
// ANSI SEQUENCE INTRODUCERS
//==============================================================================

/// Escape sequence initiator
const String ESC = '\x1B';

/// Control Sequence Introducer (CSI)
const String CSI = '\x1B[';

/// Device Control String
const String DCS = '\x1BP';

/// Operating System Command
const String OSC = '\x1B]';

//==============================================================================
// CURSOR CONTROL SEQUENCES
//==============================================================================

/// Request cursor position report
@_Ansi()
const String cursorPositionQuery = '${CSI}6n';

/// Move cursor to home position (1,1)
@_Ansi()
const String cursorToHome = '${CSI}H';

/// Move cursor to specific position
@_Ansi()
String cursorTo(int line, int column) => '${CSI}$line;${column}H';

/// Move cursor up by specified number of lines
@_Ansi()
String cursorUp(int lines) => '${CSI}${lines}A';

/// Move cursor down by specified number of lines
@_Ansi()
String cursorDown(int lines) => '${CSI}${lines}B';

/// Move cursor forward by specified number of columns
@_Ansi()
String cursorForward(int columns) => '${CSI}${columns}C';

/// Move cursor backward by specified number of columns
@_Ansi()
String cursorBackward(int columns) => '${CSI}${columns}D';

/// Move cursor to beginning of next line
@_Ansi()
const String cursorNextLine = '${CSI}E';

/// Move cursor to beginning of previous line
@_Ansi()
const String cursorPrevLine = '${CSI}F';

/// Move cursor to specified column in current line
@_Ansi()
String cursorToColumn(int column) => '${CSI}${column}G';

/// Moves cursor down one line; if at bottom of scroll region,
/// scrolls screen up one line
@_Ansi()
const String cursorDownScroll = '\x1BD';

/// Moves cursor up one line; if at top of scroll region,
/// scrolls screen down one line
@_Ansi()
const String cursorUpScroll = '\x1BM';

//==============================================================================
// INPUT MODES
//==============================================================================

/// Enables to differentiate between normal numbers and the keypad
@_DEC()
const String enableApplicationKeypadMode = '\x1B=';

/// Disables to differentiate between normal numbers and the keypad
@_DEC()
const String disableApplicationKeypadMode = '\x1B>';

@_Xterm()
/// Enables making it easier to differentiate between input and pasted input
const String enableBracketedPaste = '$CSI?2004h';

@_Xterm()
/// Disables making it easier to differentiate between input and pasted input
const String disableBracketedPaste = '$CSI?2004l';

//==============================================================================
// CURSOR STATE MANAGEMENT
//==============================================================================

/// Save cursor position
@_DEC()
const String saveCursorPosition = '\x1B7';

/// Restore cursor position
@_DEC()
const String restoreCursorPosition = '\x1B8';

//==============================================================================
// CURSOR APPEARANCE
//==============================================================================

/// Hide the cursor
@_DEC()
const String hideCursor = '${CSI}?25l';

/// Show the cursor
@_DEC()
const String showCursor = '${CSI}?25h';

@_DEC()
String changeCursorAppearance({
  CursorType cursorType = CursorType.block,
  bool blinking = true,
}) {
  final decPrivateMode = switch ((cursorType, blinking)) {
    (CursorType.block, true) => 0,
    (CursorType.block, false) => 2,
    (CursorType.verticalBar, true) => 3,
    (CursorType.verticalBar, false) => 4,
    (CursorType.underline, true) => 5,
    (CursorType.underline, false) => 6,
  };
  return '${CSI}${decPrivateMode}q';
}

/// Enable cursor blinking (not reliable => use [changeCursorAppearance)
@_DEC()
const String enableCursorBlink = '${CSI}?12l';

/// Disable cursor blinking (not reliable => use [changeCursorAppearance)
@_DEC()
const String disableCursorBlink = '${CSI}?12h';

//==============================================================================
// WINDOW MANIPULATION
//==============================================================================

/// Change terminal window dimensions (ignored on windows)
@_Xterm()
String changeWindowDimension(int width, int height) =>
    '${CSI}8;$height;${width}t';

/// Set terminal window title
@_Xterm()
String changeTerminalTitle(String title) => '${OSC}0;$title\x07';

/// Set terminal window icon
///
/// Is also a title but showed differently than [changeTerminalTitle]
/// by some terminals.
@_Xterm()
String changeTerminalIcon(String icon) => '${OSC}1;$icon\x07';

//==============================================================================
// SCREEN CLEARING AND ERASING
//==============================================================================

/// Erase from cursor to end of screen
@_Ansi()
const String eraseScreenFromCursor = '${CSI}J';

/// Erase from start of screen to cursor
@_Ansi()
const String eraseScreenToCursor = '${CSI}1J';

/// Erase entire screen
@_Ansi()
const String eraseEntireScreen = '${CSI}2J';

/// Erase from cursor to end of line
@_Ansi()
const String eraseLineFromCursor = '${CSI}K';

/// Erase from start of line to cursor
@_Ansi()
const String eraseLineToCursor = '${CSI}1K';

/// Erase entire line
@_Ansi()
const String eraseEntireLine = '${CSI}2K';

//==============================================================================
// TEXT FORMATTING
//==============================================================================

/// Reset all text formatting
@_Ansi()
const String resetAllFormats = '${CSI}0m';

/// Enable bold text
@_Ansi()
const String boldText = '${CSI}1m';

/// Enable dim/faint text
@_Ansi()
const String dimText = '${CSI}2m';

/// Enable italic text
@_Ansi()
const String italicText = '${CSI}3m';

/// Enable underlined text
@_Ansi()
const String underlineText = '${CSI}4m';

/// Enable blinking text
@_Ansi()
const String blinkingText = '${CSI}5m';

/// Enable inverse/reversed colors
@_Ansi()
const String inverseText = '${CSI}7m';

/// Enable hidden/invisible text
@_Ansi()
const String hiddenText = '${CSI}8m';

/// Enable strikethrough text
@_Ansi()
const String strikethroughText = '${CSI}9m';

//==============================================================================
// TEXT FORMAT RESET
//==============================================================================

/// Reset bold and dim attributes
@_Ansi()
const String resetBoldDim = '${CSI}22m';

/// Reset italic attribute
@_Ansi()
const String resetItalic = '${CSI}23m';

/// Reset underline attribute
@_Ansi()
const String resetUnderline = '${CSI}24m';

/// Reset blink attribute
@_Ansi()
const String resetBlink = '${CSI}25m';

/// Reset inverse/reversed colors
@_Ansi()
const String resetInverse = '${CSI}27m';

/// Reset hidden/invisible attribute
@_Ansi()
const String resetHidden = '${CSI}28m';

/// Reset strikethrough attribute
@_Ansi()
const String resetStrikethrough = '${CSI}29m';

//==============================================================================
// COLOR CONTROL
//==============================================================================

/// Reset to default color in foreground
@_Ansi()
const String defaultForegroundColor = '${CSI}39m';

/// Reset to default color in background
@_Ansi()
const String defaultBackgroundColor = '${CSI}39m';

/// Set foreground color using color code
@_Ansi()
String foregroundColor(int colorCode) => '${CSI}${colorCode}m';

/// Set background color using color code
@_Ansi()
String backgroundColor(int colorCode) => '${CSI}${colorCode + 10}m';

/// Set 16-color ANSI color
@_Ansi()
String ansi16Color(int colorCode, {bool isForeground = true}) =>
    '${CSI}${isForeground ? 3 : 4}${colorCode}m';

/// Set bright ANSI color
@_Ansi()
String ansiBrightColor(int colorCode, {bool isForeground = true}) =>
    '${CSI}${isForeground ? 9 : 10}${colorCode}m';

//==============================================================================
// EXTENDED COLOR SUPPORT
//==============================================================================

/// Set foreground color using 256-color palette
@_Xterm(alwaysSupported: false)
String fg256Color(int colorId) => '${CSI}38;5;${colorId}m';

/// Set background color using 256-color palette
@_Xterm(alwaysSupported: false)
String bg256Color(int colorId) => '${CSI}48;5;${colorId}m';

/// Set foreground color using RGB values
@_Xterm(alwaysSupported: false)
String fgRGBColor(int r, int g, int b) => '${CSI}38;2;$r;$g;${b}m';

/// Set background color using RGB values
@_Xterm(alwaysSupported: false)
String bgRGBColor(int r, int g, int b) => '${CSI}48;2;$r;$g;${b}m';

//==============================================================================
// SCREEN MODE CONTROL
//==============================================================================

/// Enable line wrapping
@_DEC()
const String enableLineWrapping = '${CSI}?7h';

/// Disable line wrapping
@_DEC()
const String disableLineWrapping = '${CSI}?7l';

//==============================================================================
// TERMINAL BUFFER CONTROL
//==============================================================================

/// Switch to alternate screen buffer
@_DEC()
const String enableAlternativeBuffer = '${CSI}?1049h';

/// Switch back to main screen buffer
@_DEC()
const String disableAlternativeBuffer = '${CSI}?1049l';

/// Save current screen
@_DEC()
const String saveScreen = '${CSI}?47h';

/// Restore saved screen
@_DEC()
const String restoreScreen = '${CSI}?47l';

//==============================================================================
// FOCUS AND MOUSE TRACKING
//==============================================================================

/// Enable terminal focus events
@_Xterm(alwaysSupported: false)
const String enableFocusTracking = "\u001B[?1004h";

/// Disable terminal focus events
@_Xterm(alwaysSupported: false)
const String disableFocusTracking = "\u001B[?1004l";

/// Enable mouse tracking (motion, button, and SGR encoding)
@_Xterm(alwaysSupported: false)
const String enableMouseEvents = "\u001B[?1003;1006h";

/// Disable mouse tracking
@_Xterm(alwaysSupported: false)
const String disableMouseEvents = "\u001B[?1003;1006l";

//==============================================================================
// KEYBOARD AND FUNCTION KEYS
//==============================================================================

/// Generate keyboard escape sequence
String keyboardString(String code) => '${CSI}${code}~';

/// Generate function key escape sequence
String fKey(int n) => keyboardString('1${n - 1}');

/// Common keyboard code mappings for function and special keys
final Map<String, String> keyboardCodes = {
  'F1': '0;59',
  'F2': '0;60',
  'F3': '0;61',
  'F4': '0;62',
  'F5': '0;63',
  'F6': '0;64',
  'F7': '0;65',
  'F8': '0;66',
  'F9': '0;67',
  'F10': '0;68',
  'F11': '0;133',
  'F12': '0;134',
  'HOME': '0;71',
  'UP': '0;72',
  'PGUP': '0;73',
  'LEFT': '0;75',
  'RIGHT': '0;77',
  'END': '0;79',
  'DOWN': '0;80',
  'PGDN': '0;81',
  'INS': '0;82',
  'DEL': '0;83',
  'ENTER': '13',
  'BACKSPACE': '8',
  'TAB': '9',
};

/// Generate keyboard escape sequence with modifiers
String keyCode(
  String key, {
  bool shift = false,
  bool ctrl = false,
  bool alt = false,
}) {
  if (!keyboardCodes.containsKey(key)) return '';
  String baseCode = keyboardCodes[key]!;
  if (shift) baseCode = '0;${int.parse(baseCode.split(';')[1]) + 25}';
  if (ctrl) baseCode = '0;${int.parse(baseCode.split(';')[1]) + 35}';
  if (alt) baseCode = '0;${int.parse(baseCode.split(';')[1]) + 45}';
  return '${CSI}${baseCode}~';
}
