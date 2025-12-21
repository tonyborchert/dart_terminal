import 'dart:convert';
import 'dart:io';

import 'package:convert/convert.dart';

// the latin1, and uft8, and ascii is copied from dart:convert source code
Map<String, Encoding> _encodings = {
  // ISO_8859-1:1987.
  "iso_8859-1:1987": latin1,
  "iso-ir-100": latin1,
  "iso_8859-1": latin1,
  "iso-8859-1": latin1,
  "latin1": latin1,
  "l1": latin1,
  "ibm819": latin1,
  "cp819": latin1,
  "csisolatin1": latin1,
  'latin2': latin2,
  'iso-8859-2': latin2,
  'l2': latin2,

  'latin3': latin3,
  'iso-8859-3': latin3,
  'l3': latin3,

  'latin4': latin4,
  'iso-8859-4': latin4,
  'l4': latin4,

  'latin5': latin5,
  'iso-8859-9': latin5,
  'l5': latin5,

  'latin6': latin6,
  'iso-8859-10': latin6,
  'l6': latin6,

  'latin7': latin7,
  'iso-8859-13': latin7,
  'l7': latin7,

  'latin8': latin8,
  'iso-8859-14': latin8,
  'l8': latin8,

  'latin9': latin9,
  'iso-8859-15': latin9,
  'l9': latin9,

  'latin10': latin10,
  'iso-8859-16': latin10,
  'l10': latin10,

  // Cyrillic
  'latincyrillic': latinCyrillic,
  'iso-8859-5': latinCyrillic,
  'koi8-r': latinCyrillic,
  'koi8-u': latinCyrillic,

  // Greek
  'latingreek': latinGreek,
  'iso-8859-7': latinGreek,

  // Hebrew
  'latinhebrew': latinHebrew,
  'iso-8859-8': latinHebrew,

  // Arabic
  'latinarabic': latinArabic,
  'iso-8859-6': latinArabic,

  // Thai
  'latinthai': latinThai,
  'iso-8859-11': latinThai,

  // US-ASCII.
  "iso-ir-6": ascii,
  "ansi_x3.4-1968": ascii,
  "ansi_x3.4-1986": ascii,
  "iso_646.irv:1991": ascii,
  "iso646-us": ascii,
  "us-ascii": ascii,
  "us": ascii,
  "ibm367": ascii,
  "cp367": ascii,
  "csascii": ascii,
  "ascii": ascii, // This is not in the IANA official names.
  // UTF-8.
  "csutf8": utf8,
  "utf-8": utf8,
};

Future<Encoding> detectSystemEncoding() async {
  if (Platform.isWindows) {
    try {
      // Run chcp command to get code page
      final result = await Process.run('chcp', []);
      final output = result.stdout.toString();
      final match = RegExp(r'Active code page: (\d+)').firstMatch(output)!;
      final codePage = int.parse(match.group(1)!);
      switch (codePage) {
        // Latin-1
        case 850:
        case 437:
        case 1252:
          return latin1;
        // Latin-2
        case 28592:
          return latin2;
        // Latin-3
        case 28593:
          return latin3;
        // Latin-4
        case 28594:
          return latin4;
        // Latin-5 / Turkish
        case 28599:
          return latin5;
        // Latin-6 / Nordic
        case 28600:
          return latin6;
        // Latin-7 / Baltic
        case 28603:
          return latin7;
        // Latin-8 / Celtic
        case 28604:
          return latin8;
        // Latin-9 / Euro
        case 28605:
          return latin9;
        // Latin-10 / South-East Europe
        case 28616:
          return latin10;
        // Cyrillic
        case 28595:
          return latinCyrillic;
        // Greek
        case 28597:
          return latinGreek;
        // Hebrew
        case 28598:
          return latinHebrew;
        // Arabic
        case 28596:
          return latinArabic;
        // Thai
        case 28611:
          return latinThai;
        case 65001:
        default:
          return utf8; // codePage would be '65001'
      }
    } catch (_) {}
  }
  // Check locale environment variables
  final lang = Platform.environment['LANG'];
  final lcCtype = Platform.environment['LC_CTYPE'] ?? lang;
  if (lcCtype != null) {
    late String encodingName;
    if (lcCtype.contains('.')) {
      encodingName = lcCtype.split('.').last.toLowerCase();
    } else {
      encodingName = lcCtype.toLowerCase();
    }
    return _encodings[encodingName] ?? utf8;
  }
  return utf8;
}
