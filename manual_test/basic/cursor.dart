import 'dart:io';

import 'package:dart_terminal/ansi.dart';

/// TODO: fix cursor support
void main() async {
  final terminalService = AnsiTerminalService.agnostic();
  final v = terminalService.viewport;

  terminalService.listener = TerminalListener(
    onControlCharacter: (c) async {
      if ([ControlCharacter.ctrlC, ControlCharacter.ctrlZ].contains(c)) {
        await terminalService.detach();
        exit(0);
      }
      if (v.cursor == null) return;
      final cursorType = switch (c) {
        ControlCharacter.ctrlA => CursorType.block,
        ControlCharacter.ctrlS => CursorType.verticalBar,
        ControlCharacter.ctrlD => CursorType.underline,
        _ => v.cursor!.type,
      };
      final vec = switch (c) {
        ControlCharacter.arrowUp => -e2,
        ControlCharacter.arrowRight => e1,
        ControlCharacter.arrowDown => e2,
        ControlCharacter.arrowLeft => -e1,
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
