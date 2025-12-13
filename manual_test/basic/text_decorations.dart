import 'dart:io';

import 'package:dart_terminal/ansi.dart';

class TextDecorationsListener extends DefaultTerminalListener {
  @override
  void controlCharacter(KeyStrokes c) async {
    if (c == KeyStrokes.ctrlZ) {
      await service.detach();
      exit(0);
    }
    if (c == KeyStrokes.ctrlA) {
      style += 1;
      paint();
    }
    if (c == KeyStrokes.ctrlB) {
      style += 32;
      paint();
    }
    if (c == KeyStrokes.ctrlS) {
      style -= 1;
      paint();
    }
  }

  @override
  void screenResize(Size size) {
    paint();
  }
}

final service = AnsiTerminalService.agnostic()
  ..listener = TextDecorationsListener();
final viewport = service.viewport;
int style = 0;

TextEffects s(int encodedStyle) => TextEffects(
  intense: encodedStyle & 1 != 0,
  faint: encodedStyle & 2 != 0,
  italic: encodedStyle & 4 != 0,
  crossedOut: encodedStyle & 8 != 0,
  doubleUnderline: encodedStyle & 16 != 0,
  fastBlink: encodedStyle & 32 != 0,
  slowBlink: encodedStyle & 64 != 0,
  underline: encodedStyle & 128 != 0,
);

void paint() {
  viewport.drawText(
    text: "Press ctrl-A",
    style: TextStyle(
      effects: s(style),
      color: Colors.red,
      backgroundColor: Colors.blue,
    ),
    position: Position(0, 0),
  );
  viewport.drawText(
    text: " or ctrl-S",
    style: TextStyle(
      effects: s(~style),
      color: Colors.red,
      backgroundColor: Colors.blue,
    ),
    position: Position(12, 0),
  );
  viewport.updateScreen();
}

void main() async {
  await service.attach();
  service.viewPortMode();
  paint();
}
