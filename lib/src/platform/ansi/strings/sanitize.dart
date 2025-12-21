export "package:wcwidth/wcwidth.dart";


// Matches all control characters except format characters (Cf)
// and for tab (U+0009) and line feed (U+000A)
// (carriage return is matched, space is not matched)
final _nonPrintableRegex = RegExp(
    r'[\p{Cc}&&[^\u0009\u000A]]|\p{Cs}|\p{Co}|\p{Cn}',
    unicode: true
);

String _sanitizeAnsi(String s) {
  return s.replaceAll(_nonPrintableRegex, '');
}

// TODO: try to remove malformed unicode grapheme clusters
// String _sanitizeUnicode(String s) {
// }

/*
MIT License

Copyright (c) Sindre Sorhus <sindresorhus@gmail.com> (https://sindresorhus.com)

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

// Valid string terminator sequences are BEL, ESC\, and 0x9c
const ST = '(?:\\u0007|\\u001B\\u005C|\\u009C)';

// OSC sequences only: ESC ] ... ST (non-greedy until the first ST)
const osc = "(?:\\u001B\\][\\s\\S]*?${ST})";

// CSI and related: ESC/C1, optional intermediates, optional params (supports ; and :) then final byte
const csi = '[\\u001B\\u009B][[\\]()#;?]*(?:\\d{1,4}(?:[;:]\\d{0,4})*)?[\\dA-PR-TZcf-nq-uy=><~]';

final escapeCodePattern = RegExp("${osc}|${csi}");

String _sanitizeEscapeCodes(String s) {
  return s.replaceAll(escapeCodePattern, '');
}

String sanitize(String s) {
  var sanitized = _sanitizeAnsi(s);
  sanitized = _sanitizeEscapeCodes(sanitized);
  return sanitized;
}
