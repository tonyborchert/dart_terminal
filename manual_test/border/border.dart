import 'dart:io';

import 'package:dart_terminal/ansi.dart';
import 'package:dart_terminal/src/platform/ansi/escape_codes.dart';

class ExitListener extends DefaultTerminalListener {
  @override
  void controlCharacter(ControlCharacter controlCharacter) async {
    if (controlCharacter == ControlCharacter.ctrlZ) {
      await service.detach();
      exit(0);
    }
  }

  @override
  void screenResize(Size size) => draw();
}

void draw() {
  final id = BorderDrawIdentifier();
  final style = BorderCharSet.rounded();
  viewport.drawBorderBox(
    rect: Position(5, 5) & Size(10, 10),
    style: style,
    drawId: id,
  );
  viewport.drawBorderBox(
    rect: Position(8, 8) & Size(10, 10),
    style: style,
    drawId: id,
  );
  viewport.drawBorderLine(
    from: Position(8, 10),
    to: Position(17, 10),
    style: style,
    drawId: id,
  );

  viewport.updateScreen();
}

final service = AnsiTerminalService.agnostic()..listener = ExitListener();
final viewport = service.viewport;

void main() async {
  await service.attach();
  service.viewPortMode();
  draw();
}
