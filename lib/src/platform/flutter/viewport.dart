// Project imports:
import 'package:dart_terminal/core.dart';
import 'package:dart_terminal/src/platform/shared/buffer_viewport.dart';

class FlutterTerminalViewport extends BufferTerminalViewport {
  bool hasSize = false;
  late Size _size;
  Size get size => _size;
  late void Function() onChanged;

  void updateSize(Size size) {
    hasSize = true;
    _size = size;
    resizeBuffer();
  }

  CursorState? _cursor = CursorState(position: Position.topLeft);
  @override
  CursorState? get cursor => _cursor;
  set cursor(CursorState? cursor) {
    _cursor = cursor;
    onChanged();
  }


  /// TODO: grapheme and newGrapheme needed in cell to actually display everything correctly
  @override
  void updateScreen() {
    for (int y = 0; y < size.height; y++) {
      if (!checkRowChanged(y)) continue;
      final row = getRow(y);
      for (int x = 0; x < size.width; x++) {
        final cell = row[x];
        final cellPos = Position(x, y);
        if (cell.changed) {
          final grapheme = cell.grapheme;
          if (grapheme != null && validateGraphemeAndCalculateDiff(cellPos)) {
            if (!grapheme.isSecond) {
              x += grapheme.width - 1;
            }
            setRowChanged(y);
            continue;
          }
          if (cell.calculateDifference()) {
            cell.changed = false;
          }
        }
      }
    }
    onChanged();
  }
}
