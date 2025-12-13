import 'dart:io';

import 'package:dart_terminal/ansi.dart';

class ControlTerminalInputListener extends DefaultTerminalListener {
  @override
  void keyboardInput(KeyboardInput controlCharacter) async {
    if (controlCharacter == KeyStrokes.ctrlZ) {
      await service.detach();
      exit(0);
    }
  }

  static bool isPressed = false;
  static int codePoint = 0;
  @override
  void mouseEvent(MouseEvent event) {
    Position? motionPos;
    switch (event) {
      case MouseScrollEvent(
        vec: Offset(dx: var x, dy: var y),
        position: var pos,
      ):
        codePoint += x + y;
        for (int i = -10; i <= 10; i++) {
          for (int j = -10; j <= 10; j++) {
            viewport.drawPoint(
              position: Position(pos.x + i, pos.y + j),
              foreground: Foreground(
                style: ForegroundStyle(
                  effects: TextEffects.underline,
                  color: i != 0 || j != 0 ? Colors.green : Colors.yellow,
                ),
                codeUnit: (codePoint % 26) + 65,
              ),
            );
          }
        }
      case MousePressEvent(buttonState: var t, position: var pos):
        motionPos = pos;
        if (t == MouseButtonState.released) {
          isPressed = false;
        } else {
          isPressed = true;
        }
      case MouseMotionEvent(position: var pos):
        motionPos = pos;
    }
    if (motionPos != null) {
      viewport.drawPoint(
        position: motionPos,
        background: isPressed ? Colors.red : Colors.brightRed,
      );
    }
    viewport.updateScreen();
  }
}

final service = AnsiTerminalService.agnostic()
  ..listener = ControlTerminalInputListener();
final viewport = service.viewport;

void main() async {
  await service.attach();
  service.viewPortMode();
}
