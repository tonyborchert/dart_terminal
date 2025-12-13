import 'dart:convert';
import 'dart:io' as io;

import 'package:dart_terminal/src/platform/ansi/controller.dart';
import 'package:dart_terminal/src/platform/ansi/escape_codes.dart';

void main() {
  AnsiTerminalController()
    ..changeFocusTrackingMode(enable: true)
    ..setInputMode(enableRaw: true)
    ..changeBracketedPasteMode(enable: true)
    ..changeMouseTrackingMode(enable: true);
  io.stdin.listen((data) {
    final input = utf8.decode(data, allowMalformed: true);

    for (var codeUnit in input.codeUnits) {
      if ((codeUnit >= 0x00 && codeUnit <= 0x1F) || // C0
          (codeUnit >= 0x80 && codeUnit <= 0x9F) || // C1
          codeUnit == 0x7F) {
        // DEL / backspace
        io.stdout.write('\\x${codeUnit.toRadixString(16).padLeft(2, '0')}');
      } else {
        io.stdout.writeCharCode(codeUnit);
      }
    }
    io.stdout.write("\n\r");

    if (data.first == 0x1A) {
      AnsiTerminalController()
        ..changeFocusTrackingMode(enable: false)
        ..setInputMode(enableRaw: false)
        ..changeBracketedPasteMode(enable: false)
        ..changeMouseTrackingMode(enable: false);
      io.exit(0);
    }
  });
}
