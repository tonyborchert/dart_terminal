// Dart imports:
import 'dart:io' as io;

// Project imports:
import 'package:dart_terminal/core.dart';
import '../../core/style.dart';
import '../shared/buffer_viewport.dart';
import '../shared/size_tracker.dart';
import 'escape_codes.dart' as ansi_codes;
import 'controller.dart';

class AnsiTerminalViewport extends BufferTerminalViewport {
  AnsiTerminalController _controller;
  TerminalSizeTracker _sizeTracker;

  Color? _backgroundFill;

  AnsiTerminalViewport(this._controller, this._sizeTracker);

  @override
  Size get size => _sizeTracker.currentSize;

  bool _initialActivation = true;
  void activate() {
    if (_initialActivation) {
      _initialActivation = false;
      _cursorPosition = Position.topLeft;
      _cursorHidden = false;
      _cursorAppearance = (CursorType.block, true);
      _currentFg = ForegroundStyle();
      _currentBg = Color.normal();
    }
    _controller
      ..changeScreenMode(alternateBuffer: true)
      ..changeMouseTrackingMode(enable: true)
      ..setCursorPosition(_cursorPosition);
    io.stdout.write(ansi_codes.eraseEntireScreen);
    _constrainCursorPosition();
    resizeBuffer();
  }

  void deactivate() {
    _controller
      ..changeScreenMode(alternateBuffer: true)
      ..changeMouseTrackingMode(enable: false);
    _transition(ForegroundStyle(), Color.normal());
    io.stdout.write(_redrawBuff);
    _redrawBuff.clear();
  }

  void resize() {
    resizeBuffer();
    _backgroundFill = null;
    io.stdout.write(ansi_codes.eraseEntireScreen);
    resetBuffer();
    _constrainCursorPosition();
  }

  @override
  CursorState? get cursor => _cursorHidden
      ? null
      : CursorState(position: _cursorPosition!, blinking: _cursorAppearance.$2);
  late (CursorType, bool) _cursorAppearance; // (type, blinking)
  late bool _cursorHidden;
  late Position _cursorPosition;

  @override
  set cursor(CursorState? cursor) {
    if (_cursorHidden != (cursor == null)) {
      _controller.changeCursorVisibility(hiding: (cursor == null));
      _cursorHidden = (cursor == null);
    }
    if (cursor != null) {
      if ((cursor.type, cursor.blinking) != _cursorAppearance) {
        _cursorAppearance = (cursor.type, cursor.blinking);
        _controller.changeCursorAppearance(
          blinking: cursor.blinking,
          cursorType: cursor.type,
        );
      }
      if (cursor.position != _cursorPosition) {
        _controller.setCursorPositionRelative(_cursorPosition, cursor.position);
        _cursorPosition = cursor.position;
      }
      _constrainCursorPosition();
    }
  }

  void _constrainCursorPosition() {
    if (_cursorPosition != null) {
      _cursorPosition = _cursorPosition!.clamp(Position.topLeft & size);
    }
  }

  @override
  void drawColor({
    Color color = const Color.normal(),
    bool optimizeByClear = true,
  }) {
    if (optimizeByClear) {
      _backgroundFill = color;
      resetBuffer(background: color);
    } else {
      super.drawColor(color: color);
    }
  }

  final StringBuffer _redrawBuff = StringBuffer();
  late ForegroundStyle _currentFg;
  late Color _currentBg;

  /// returns if cursor has been moved
  // more optimizations possible
  // (e.g. only write x coordinate if moving horizontally)
  @override
  void updateScreen() {
    if (_backgroundFill != null) {
      _transition(ForegroundStyle(), _backgroundFill!);
      _redrawBuff.write(ansi_codes.eraseEntireScreen);
      _backgroundFill = null;
    }
    Position oldCursorPosition = _cursorPosition;
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
              _moveCursorInBuff(cellPos);
              _cursorPosition += e1 * grapheme.width;
              _transition(cell.fg.style, cell.bg);
              _redrawBuff.write(grapheme.data);
              // cell.changed = false; (keep those with a grapheme always changed)
              setRowChanged(y);
              x += grapheme.width - 1;
            }
            continue;
          }
          if (cell.calculateDifference()) {
            _moveCursorInBuff(cellPos);
            _cursorPosition += e1;
            _transition(cell.fg.style, cell.bg);
            _redrawBuff.writeCharCode(cell.fg.codeUnit);
            cell.changed = false;
          }
        }
      }
    }
    // cursor position should remain unchanged if cursor visible
    if (!_cursorHidden) {
      _moveCursorInBuff(oldCursorPosition);
    }
    io.stdout.write(_redrawBuff.toString());
    _redrawBuff.clear();
  }

  void _moveCursorInBuff(Position newPosition) {
    if (newPosition == _cursorPosition) return;
    _redrawBuff.write(
      ansi_codes.cursorTo(newPosition.y + 1, newPosition.x + 1),
    );
    _cursorPosition = newPosition;
  }

  bool _firstParameter = true;

  void _writeParameter(String s) {
    if (!_firstParameter) {
      _redrawBuff.writeCharCode(59);
    }
    _redrawBuff.write(s);
    _firstParameter = false;
  }

  void _transition(ForegroundStyle fg, Color bg) {
    final fromEffects = _currentFg.effects;
    final toEffects = fg.effects;
    final textEffectsDiff = fromEffects != toEffects;
    final foregroundColorDiff = !equalsColor(fg.color, _currentFg.color);
    final backgroundColorDiff = !equalsColor(bg, _currentBg);
    if (!textEffectsDiff) {
      if (foregroundColorDiff && backgroundColorDiff) {
        _redrawBuff.write(
          "${ansi_codes.CSI}${fgSgr(fg.color)};"
          "${bgSgr(bg)}m",
        );
        _currentFg = fg;
        _currentBg = bg;
      } else if (foregroundColorDiff) {
        _redrawBuff.write("${ansi_codes.CSI}${fgSgr(fg.color)}m");
        _currentFg = fg;
      } else if (backgroundColorDiff) {
        _redrawBuff.write("${ansi_codes.CSI}${bgSgr(bg)}m");
        _currentBg = bg;
      }
    } else if (toEffects.isEmpty) {
      _firstParameter = true;
      _redrawBuff.write(ansi_codes.CSI);
      _writeParameter("0");
      if (fg.color != const Color.normal()) {
        _writeParameter(fgSgr(fg.color));
      }
      if (bg != const Color.normal()) {
        _writeParameter(bgSgr(bg));
      }
      _redrawBuff.writeCharCode(109);
      _currentFg = fg;
      _currentBg = bg;
    } else {
      _firstParameter = true;
      _redrawBuff.write(ansi_codes.CSI);
      _currentFg = fg;
      if (foregroundColorDiff) {
        _writeParameter(fgSgr(fg.color));
      }
      if (backgroundColorDiff) {
        _writeParameter(bgSgr(bg));
        _currentBg = bg;
      }
      final changedEffects = fromEffects ^ toEffects;
      final addedEffects = toEffects & changedEffects;
      // instead iterate TextDecoration.values
      for (final effect in TextEffect.values) {
        if (effect.containedIn(changedEffects)) {
          if (effect.containedIn(addedEffects)) {
            _writeParameter(effect.onCode);
          } else {
            _writeParameter(effect.offCode);
          }
        }
      }

      // TODO: optimization to use reset like \e[0;...;...m
      _redrawBuff.writeCharCode(109);
    }
  }
}
