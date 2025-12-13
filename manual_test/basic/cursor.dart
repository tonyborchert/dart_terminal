import 'dart:io';

import 'package:dart_terminal/ansi.dart';

/// TODO: fix cursor support
void main() async {
  final terminalService = AnsiTerminalService.agnostic();
  final v = terminalService.viewport;

  terminalService.listener = TerminalListener(
    onKeyboardInput: (c) async {
      if ([KeyStrokes.ctrlC, KeyStrokes.ctrlZ].contains(c)) {
        await terminalService.detach();
        exit(0);
      }
      if (v.cursor == null) return;
      final cursorType = switch (c) {
        KeyStrokes.ctrlA => CursorType.block,
        KeyStrokes.ctrlS => CursorType.verticalBar,
        KeyStrokes.ctrlD => CursorType.underline,
        _ => v.cursor!.type,
      };
      final vec = switch (c) {
        KeyStrokes.arrowUp => -e2,
        KeyStrokes.arrowRight => e1,
        KeyStrokes.arrowDown => e2,
        KeyStrokes.arrowLeft => -e1,
        _ => Offset.zero,
      };
      v.cursor = CursorState(
        position: v.cursor!.position + vec,
        type: cursorType,
      );
    },
  );
  await terminalService.attach();
  terminalService.viewPortMode();
  v.drawUnicodeText(
    text: "Use ctrl+A, ctrl+S and ctrl+D to switch between cursor types",
    position: Position(0, 2),
  );
  v.updateScreen();
}
