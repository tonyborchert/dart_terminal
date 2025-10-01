import 'style.dart' show Color;

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

// TODO: add ansi support
enum CursorType { block, underline, verticalBar }

/// Note: button 4-7 are used for scrolling
enum MouseButton { left, right, middle, button8, button9, button10, button11 }

enum MouseButtonState { down, up }

/// Control characters and special keys that can be received as input.
///
/// These represent both standard control characters (Ctrl+key combinations)
/// and special keys like arrows and function keys.
enum ControlCharacter {
  ctrlSpace, // NULL
  ctrlA,
  ctrlB,
  ctrlC, // Break
  ctrlD, // End of File
  ctrlE,
  ctrlF,
  ctrlG, // Bell
  ctrlH, // Backspace
  tab,
  ctrlJ,
  ctrlK,
  ctrlL,
  enter,
  ctrlN,
  ctrlO,
  ctrlP,
  ctrlQ,
  ctrlR,
  ctrlS,
  ctrlT,
  ctrlU,
  ctrlV,
  ctrlW,
  ctrlX,
  ctrlY,
  ctrlZ, // Suspend
  /// Navigation keys
  arrowLeft,
  arrowRight,
  arrowUp,
  arrowDown,
  pageUp,
  pageDown,
  wordLeft,
  wordRight,

  /// Editing keys
  home,
  end,
  escape,
  delete,
  wordBackspace,

  /// Function keys F1-F4 (TODO: extend to F12)
  F1,
  F2,
  F3,
  F4,
}
