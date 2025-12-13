import 'dart:io';

import 'package:dart_terminal/ansi.dart';

void main() async {
  final terminalService = AnsiTerminalService.agnostic();
  final v = terminalService.viewport;

  terminalService.listener = TerminalListener(
    onKeyboardInput: (c) async {
      if ([KeyStrokes.ctrlC, KeyStrokes.ctrlZ].contains(c)) {
        await terminalService.detach();
        exit(0);
      }
      final vec = switch (c) {
        KeyStrokes.arrowUp => -e2,
        KeyStrokes.arrowRight => e1,
        KeyStrokes.arrowDown => e2,
        KeyStrokes.arrowLeft => -e1,
        _ => Offset.zero,
      };
      v.cursor = CursorState(position: v.cursor!.position + vec);
    },
  );
  await terminalService.attach();
  terminalService.viewPortMode();
  v.drawUnicodeText(text: "😺", position: Position(v.size.width - 1, 0));
  v.drawUnicodeText(
    text:
        "all dog emoji should be replaced max after 1 second, instead there should be the text 'a  a' and '𐌀  𐌀'",
    position: Position(0, 0),
  );
  v.drawUnicodeText(
    text:
        "cat emoji down below should move to the right then back to the left"
        "and repeating, (color should stay until replaced by new cat)",

    position: Position(0, 2),
  );
  v.drawText(text: "move cursor with arrows", position: Position(0, 4));

  v.drawUnicodeText(
    text:
        "here should be 5 symbols directly next to eachother"
        " (4 with width=2, 1 with width = 1): 😀中a̴̅͆Ａ🀄",
    position: Position(0, 5),
  );
  v.drawUnicodeText(text: "🐕🐕", position: Position(0, 1));
  v.updateScreen();
  await Future.delayed(Duration(seconds: 1));
  v.drawText(text: "a", position: Position(0, 1));
  v.drawText(text: "a", position: Position(3, 1));
  v.updateScreen();
  await Future.delayed(Duration(seconds: 1));
  v.drawUnicodeText(text: "🐕🐕", position: Position(0, 1));
  v.drawText(text: "a", position: Position(0, 1));
  v.drawText(text: "a", position: Position(3, 1));
  v.updateScreen();
  await Future.delayed(Duration(seconds: 1));
  v.drawUnicodeText(text: "🐕🐕", position: Position(0, 1));
  v.updateScreen();
  await Future.delayed(Duration(seconds: 1));
  v.drawUnicodeText(text: "𐌀", position: Position(0, 1));
  v.drawUnicodeText(text: "𐌀", position: Position(3, 1));
  v.updateScreen();
  await Future.delayed(Duration(seconds: 1));
  v.drawUnicodeText(text: "🐕🐕", position: Position(0, 1));
  v.drawUnicodeText(text: "𐌀", position: Position(0, 1));
  v.drawUnicodeText(text: "𐌀", position: Position(3, 1));
  v.updateScreen();
  int color = 0;
  while (1 == 1) {
    v.drawUnicodeText(
      text: "😺",
      position: Position(0, 3),
      style: TextStyle(backgroundColor: Color.optimizedExtended(color++)),
    );
    v.updateScreen();
    await Future.delayed(Duration(seconds: 1));
    v.drawUnicodeText(
      text: "😺",
      position: Position(1, 3),
      style: TextStyle(backgroundColor: Color.optimizedExtended(color++)),
    );
    v.updateScreen();
    await Future.delayed(Duration(seconds: 1));
  }
}
