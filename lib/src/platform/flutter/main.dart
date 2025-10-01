// Flutter imports:
import 'package:flutter/material.dart' hide TextStyle, Color;

// Project imports:
import 'package:dart_terminal/core.dart';
import 'package:dart_terminal/src/platform/flutter/viewport.dart';
import 'terminal_view.dart';

void main() async {
  final viewport = FlutterTerminalViewport();
  final lambda = TerminalListener(onInput: (a) => print(a));
  runApp(
    MaterialApp(
      home: SizedBox.expand(
        child: TerminalView(
          terminalViewport: viewport,
          terminalListener: lambda,
          autofocus: true,
        ),
      ),
    ),
  );

  await Future.delayed(Duration(milliseconds: 1000));
  viewport.drawUnicodeText(
    text: "😺",
    position: Position(viewport.size.width - 1, 0),
  );
  viewport.drawUnicodeText(
    text:
        "all dog emoji should be replaced max after 1 second, instead there should be the text 'a  a' and '𐌀  𐌀'",
    position: Position(0, 0),
  );
  viewport.drawUnicodeText(
    text:
        "cat emoji down below should move to the right then back to the left"
        "and repeating, (color should stay until replaced by new cat)",

    position: Position(0, 2),
  );
  viewport.drawText(text: "move cursor with arrows", position: Position(0, 4));

  viewport.drawUnicodeText(
    text:
        "here should be 5 symbols directly next to eachother"
        " (4 with width=2, 1 with width = 1): 😀中a̴̅͆Ａ🀄",
    position: Position(0, 5),
  );
  viewport.drawUnicodeText(text: "🐕🐕", position: Position(0, 1));
  viewport.updateScreen();
  await Future.delayed(Duration(seconds: 1));
  viewport.drawText(text: "a", position: Position(0, 1));
  viewport.drawText(text: "a", position: Position(3, 1));
  viewport.updateScreen();
  await Future.delayed(Duration(seconds: 1));
  viewport.drawUnicodeText(text: "🐕🐕", position: Position(0, 1));
  viewport.drawText(text: "a", position: Position(0, 1));
  viewport.drawText(text: "a", position: Position(3, 1));
  viewport.updateScreen();
  await Future.delayed(Duration(seconds: 1));
  viewport.drawUnicodeText(text: "🐕🐕", position: Position(0, 1));
  viewport.updateScreen();
  await Future.delayed(Duration(seconds: 1));
  viewport.drawUnicodeText(text: "𐌀", position: Position(0, 1));
  viewport.drawUnicodeText(text: "𐌀", position: Position(3, 1));
  viewport.updateScreen();
  await Future.delayed(Duration(seconds: 1));
  viewport.drawUnicodeText(text: "🐕🐕", position: Position(0, 1));
  viewport.drawUnicodeText(text: "𐌀", position: Position(0, 1));
  viewport.drawUnicodeText(text: "𐌀", position: Position(3, 1));
  viewport.updateScreen();
  int color = 0;
  while (1 == 1) {
    viewport.drawUnicodeText(
      text: "😺",
      position: Position(0, 3),
      style: TextStyle(backgroundColor: Color.optimizedExtended(color++ % 256)),
    );
    viewport.updateScreen();
    await Future.delayed(Duration(seconds: 1));
    viewport.drawUnicodeText(
      text: "😺",
      position: Position(1, 3),
      style: TextStyle(backgroundColor: Color.optimizedExtended(color++ % 256)),
    );
    viewport.updateScreen();
    await Future.delayed(Duration(seconds: 1));
  }

  await Future.delayed(Duration(milliseconds: 500));
  viewport.cursor = CursorState(
    position: Position(1, 1),
    type: CursorType.verticalBar,
  );
  int plus = 0;

  while (true) {
    await Future.delayed(Duration(milliseconds: 1000 ~/ 60));
    for (int j = 0; j < viewport.size.height; j++) {
      for (int i = 0; i < viewport.size.width; i++) {
        final color = Color.optimizedExtended((plus + i + j) % 256);
        viewport.drawPoint(position: Position(i, j), background: color);
      }
    }
    viewport.updateScreen();
    plus++;
  }
  // for (int i = 0; i < 1000000; i++) {
  //   await Future.delayed(Duration(seconds: 1));
  //   viewport.drawingBuffer[5].setCodePoint(i, "a".codeUnitAt(0));
  //   viewport.updateScreen();
  // }
}
