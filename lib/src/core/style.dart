// Project imports:
import 'package:characters/characters.dart';

import 'terminal.dart' show Capability;

/// Terminal color representation system supporting different color formats.
///
/// [Color.normal] is the default color of a terminal and therefore always supported.
///
/// All other colors depend on terminal capabilities, see [Capability].
/// [Color.standard] represents the standard 8 terminal colors.
/// [Color.bright] represents the bright versions of the standard colors.
/// [Color.ansi] is a convenience constructor for the standard 16 ANSI colors
/// [Color.extended] represents the extended 256-color palette (often known as x
/// term-256).
/// [Color.rgb] represents full 24-bit RGB colors.
extension type const Color._(({String fgSgr, String bgSgr, int data}) _) {
  /// The default terminal color.
  const Color.normal()
    : this._((fgSgr: "39", bgSgr: "49", data: colorNormalType));

  /// The standard 8 terminal colors.
  ///
  /// Make sure that [number] is between 0 and 7.
  const Color.standard(int number)
    : this._((
        fgSgr: "${30 + number}",
        bgSgr: "${40 + number}",
        data: number | colorStandardType,
      ));

  /// The standard 8 bright terminal colors.
  ///
  /// Make sure that [number] is between 0 and 7.
  const Color.bright(int number)
    : this._((
        fgSgr: "${90 + number}",
        bgSgr: "${100 + number}",
        data: number | colorBrightType,
      ));

  /// The standard 16 ANSI colors (8 normal + 8 bright).
  /// The 0-7 correspond to [Color.standard] colors,
  /// the 8-15 correspond to [Color.bright] colors.
  ///
  /// Make sure that [number] is between 0 and 15.
  const Color.ansi(int number)
    : this._((
        fgSgr: number < 8 ? "${30 + number}" : "${90 + (number - 8)}",
        bgSgr: number < 8 ? "${40 + number}" : "${100 + (number - 8)}",
        data: number < 8
            ? (number | colorNormalType)
            : (number | colorBrightType),
      ));

  /// The extended 256-color palette (often known as xterm-256).
  ///
  /// The first 16 colors correspond to the standard and bright colors,
  /// but could theoretically be mapped differently by the terminal.
  /// Using [Color.optimizedExtended] uses these mappings instead.
  ///
  /// To dynamically create extended colors,
  /// use [Color.optimizedExtended] instead.
  ///
  /// Make sure that [number] is between 0 and 255.
  const Color.extended(int number)
    : this._((
        fgSgr: "38;5;$number",
        bgSgr: "48;5;$number",
        data: number | colorExtendedType,
      ));

  /// The preferred constructor for extended colors
  /// if the extended colors are created dynamically.
  ///
  /// Will also [Color.bright] or [Color.standard] if the number
  /// corresponds to a standard or bright color
  /// even though these could theoretically be mapped differently
  /// than the actual [Color.extended].
  ///
  /// Supported if [Capability.extended] is supported (which is rare).
  ///
  /// Make sure that [number] is between 0 and 255.
  factory Color.optimizedExtended(int number) {
    assert(number >= 0 && number < 256);
    return _extendedColors[number];
  }

  const Color._rgbOptimizedForBackground(int r, int g, int b, int rgb)
    : this._((fgSgr: "", bgSgr: "48;2;$r;$g;$b", data: rgb));

  const Color._rgb(int r, int g, int b, int rgb)
    : this._((fgSgr: "38;2;$r;$g;$b", bgSgr: "48;2;$r;$g;$b", data: rgb));

  /// Create an RGB color from red, green, and blue components (0–255).
  ///
  /// Supported if [Capability.trueColors] is supported (which is rare).
  const Color.rgb({int r = 0, int g = 0, int b = 0})
    : this._rgb(r, g, b, r * 256 * 256 + g * 256 + b);

  const Color.rgbOptimizedForBackground({int r = 0, int g = 0, int b = 0})
    : this._rgbOptimizedForBackground(r, g, b, r * 256 * 256 + g * 256 + b);

  /// Create an RGB color from a 24-bit integer value (0xRRGGBB).
  ///
  /// Supported if [Capability.trueColors] is supported (which is rare).
  const Color.rgbRaw(int color)
    : this._rgb(
        color ~/ 256 ~/ 256,
        (color % (256 * 256)) ~/ 256,
        color % 256,
        color,
      );

  const Color.rgbRawOptimizedForBackground(int color)
    : this._rgb(
        color ~/ 256 ~/ 256,
        (color % (256 * 256)) ~/ 256,
        color % 256,
        color,
      );

  int get _data => _.data & ~_colorTypeMask;
  int get _type => _.data & _colorTypeMask;
}

/// A set of text effects that can be applied to text in a terminal.
///
/// Not all effects are supported by all terminals. Some terminals may
/// interpret these effects differently or not support them at all.
/// There are matching [Capability]s for each effect.
///
/// See the constants for information on the different effects.
///
/// Note: Some effects are mutually exclusive and enabling one
/// will disable the other, e.g. [intense] and [faint],
/// therefore it is not recommended to combine them.
extension type const TextEffects._(int _data) {
  /// Constructor to apply multiple effects at once.
  const TextEffects({
    bool intense = false,
    bool faint = false,
    bool italic = false,
    bool underline = false,
    bool doubleUnderline = false,
    bool slowBlink = false,
    bool fastBlink = false,
    bool crossedOut = false,
  }) : this._(
         ((intense ? 1 : 0) << 0) +
             ((faint ? 1 : 0) << 1) +
             ((italic ? 1 : 0) << 2) +
             ((underline ? 1 : 0) << 3) +
             ((doubleUnderline ? 1 : 0) << 4) +
             ((slowBlink ? 1 : 0) << 5) +
             ((fastBlink ? 1 : 0) << 6) +
             ((crossedOut ? 1 : 0) << 7),
       );

  /// No text effects.
  const TextEffects.none() : this._(0);

  const TextEffects._decorationNumber(int decorationNumber)
    : this._(1 << decorationNumber);

  /// Bold or increased intensity text.
  ///
  /// Mutually exclusive with [faint].
  static const intense = TextEffects._decorationNumber(0);

  /// Decreased intensity or light font weight.
  ///
  /// Mutually exclusive with [intense].
  static const faint = TextEffects._decorationNumber(1);

  /// Italic text style.
  static const italic = TextEffects._decorationNumber(2);

  /// Single underline decoration.
  ///
  /// Mutually exclusive with [doubleUnderline].
  static const underline = TextEffects._decorationNumber(3);

  /// Double underline decoration.
  ///
  /// Mutually exclusive with [underline].
  ///
  /// Note: Some terminals may interpret this as disabling bold intensity
  /// rather than applying a double underline,
  /// therefore be sure to check the capabilities.
  static const doubleUnderline = TextEffects._decorationNumber(4);

  /// Slow blinking text.
  ///
  /// Mutually exclusive with [fastBlink].
  static const slowBlink = TextEffects._decorationNumber(5);

  /// Fast blinking text.
  ///
  /// Mutually exclusive with [slowBlink].
  static const fastBlink = TextEffects._decorationNumber(6);

  /// Crossed-out text.
  static const crossedOut = TextEffects._decorationNumber(7);

  TextEffects operator |(TextEffects other) =>
      TextEffects._(_data | other._data);
  TextEffects operator &(TextEffects other) =>
      TextEffects._(_data & other._data);
  TextEffects operator ^(TextEffects other) =>
      TextEffects._(_data ^ other._data);
  TextEffects operator ~() => TextEffects._(~_data & 0xFF);

  bool get isEmpty => _data == 0;
}

/// For internal use only.
enum TextEffect {
  /// Bold or increased intensity text.
  /// Mutually exclusive with [faint].
  intense._(1, 22, 0),

  /// Decreased intensity or light font weight.
  /// Mutually exclusive with [intense].
  faint._(2, 22, 1),

  /// Italic text style.
  italic._(3, 23, 2),

  /// Single underline decoration.
  /// Mutually exclusive with [doubleUnderline].
  underline._(4, 24, 3),

  /// Double underline decoration.
  /// Note: Some terminals may interpret this as disabling bold intensity
  /// rather than applying a double underline.
  doubleUnderline._(21, 24, 4),

  /// Slow blinking text.
  /// Mutually exclusive with [fastBlink].
  slowBlink._(5, 25, 5),

  /// Fast blinking text.
  /// Mutually exclusive with [slowBlink].
  fastBlink._(6, 25, 6),

  /// Crossed-out text.
  /// Note: Not supported in Terminal.app
  crossedOut._(9, 29, 7);

  /// ANSI SGR code for enabling this decoration
  final String onCode;

  /// ANSI SGR code for disabling this decoration
  final String offCode;

  /// Internal bit flag for decoration combinations
  final int bitFlag;

  const TextEffect._(int onCode, int offCode, int decorationNumber)
    : assert(decorationNumber < 64),
      onCode = "$onCode",
      offCode = "$offCode",
      bitFlag = 1 << decorationNumber;

  /// Returns true if this effect is included in the given [effects].
  bool containedIn(TextEffects effects) => (bitFlag & effects._data) != 0;
}

extension ToTextEffects on Iterable<TextEffect> {
  /// Combines multiple [TextEffect]s into a single [TextEffects] instance.
  TextEffects toTextEffects() {
    int data = 0;
    for (final effect in this) {
      data |= effect.bitFlag;
    }
    return TextEffects._(data);
  }
}

/// A style that can be applied to text in a terminal,
/// consisting of a foreground color, an optional background color,
/// and a set of text effects.
///
/// Not all colors and effects are supported by all terminals. Some terminals may
/// interpret these colors and effects differently or not support them at all.
/// There are matching [Capability]s for each color format and effect.
extension type const TextStyle._(
  ({Color color, Color? backgroundColor, TextEffects effects}) _
) {
  const TextStyle({
    Color color = const Color.normal(),
    Color? backgroundColor,
    TextEffects effects = const TextEffects.none(),
  }) : this._((
         color: color,
         backgroundColor: backgroundColor,
         effects: effects,
       ));

  ForegroundStyle get fgStyle =>
      ForegroundStyle(color: color, effects: textEffects);
  Color get color => _.color;
  Color? get backgroundColor => _.backgroundColor;
  TextEffects get textEffects => _.effects;
}

/// A representation of a single character with a specific foreground color
/// and text effects.
///
/// Not all colors and effects are supported by all terminals. Some terminals may
/// interpret these colors and effects differently or not support them at all.
/// There are matching [Capability]s for each color format and effect.
extension type const ForegroundStyle._(({Color color, TextEffects effects}) _) {
  const ForegroundStyle({
    Color color = const Color.normal(),
    TextEffects effects = const TextEffects.none(),
  }) : this._((color: color, effects: effects));

  Color get color => _.color;
  TextEffects get effects => _.effects;
}

/// A representation of a single character with a specific foreground color
/// and text effects.
///
/// Not all colors and effects are supported by all terminals. Some terminals may
/// interpret these colors and effects differently or not support them at all.
/// There are matching [Capability]s for each color format and effect.
extension type const Foreground._(({ForegroundStyle style, int codeUnit}) _) {
  const Foreground({
    ForegroundStyle style = const ForegroundStyle(),
    int codeUnit = 32,
  }) : this._((style: style, codeUnit: codeUnit));

  ForegroundStyle get style => _.style;

  /// single UFT-16 codeUnit which can therefore not represent all codepoints.
  int get codeUnit => _.codeUnit;
  Color get color => _.style._.color;
  TextEffects get effects => _.style._.effects;
}

/// A set of characters used to draw borders and lines in terminal UIs.
///
/// Modified from: https://github.com/onepub-dev/dart_console
/// which is forked from: https://github.com/timsneath/dart_console
/// Copyright (c) 2025 onepub-dev
/// SPDX-License-Identifier: BSD-3-Clause
class BorderCharSet {
  final String glyphs;
  const BorderCharSet.raw(this.glyphs);

  int get horizontalLine => glyphs.codeUnitAt(0);
  int get verticalLine => glyphs.codeUnitAt(1);
  int get topLeftCorner => glyphs.codeUnitAt(2);
  int get topRightCorner => glyphs.codeUnitAt(3);
  int get bottomLeftCorner => glyphs.codeUnitAt(4);
  int get bottomRightCorner => glyphs.codeUnitAt(5);
  int get cross => glyphs.codeUnitAt(6);
  int get teeUp => glyphs.codeUnitAt(7);
  int get teeDown => glyphs.codeUnitAt(8);
  int get teeLeft => glyphs.codeUnitAt(9);
  int get teeRight => glyphs.codeUnitAt(10);

  int getCorrectGlyph(bool left, bool top, bool right, bool bottom) =>
      switch ((left, top, right, bottom)) {
        // Horizontal
        (true, false, true, false) => horizontalLine,
        // Vertical
        (false, true, false, true) => verticalLine,
        // Corners
        (true, true, false, false) => bottomRightCorner,
        (false, true, true, false) => bottomLeftCorner,
        (true, false, false, true) => topRightCorner,
        (false, false, true, true) => topLeftCorner,
        // Crosses / tees
        (true, true, true, true) => cross,
        (true, false, true, true) => teeDown,
        (true, true, true, false) => teeUp,
        (false, true, true, true) => teeRight,
        (true, true, false, true) => teeLeft,
        // Single connections (fallback)
        (true, false, false, false) => horizontalLine,
        (false, true, false, false) => verticalLine,
        (false, false, true, false) => horizontalLine,
        (false, false, false, true) => verticalLine,
        // No lines (Not possible)
        (false, false, false, false) => throw UnimplementedError(),
      };

  factory BorderCharSet.none() => BorderCharSet.raw('           ');

  factory BorderCharSet.ascii() => BorderCharSet.raw('-|----+--||');

  factory BorderCharSet.asciiFilled() => BorderCharSet.raw('-|+++++++++');

  factory BorderCharSet.square() => BorderCharSet.raw('─│┌┐└┘┼┴┬┤├');

  factory BorderCharSet.rounded() => BorderCharSet.raw('─│╭╮╰╯┼┴┬┤├');

  factory BorderCharSet.bold() => BorderCharSet.raw('━┃┏┓┗┛╋┻┳┫┣');

  factory BorderCharSet.double() => BorderCharSet.raw('═║╔╗╚╝╬╩╦╣╠');
}

const _abc123 =
    'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

class AltGlyphSet {
  /// The list of alternative glyphs in the order of ABC..XYZabc..xyz123..789.
  ///
  /// They are given as a list as these glyphs are often not in the BMP.
  final List<String> glyphs;

  AltGlyphSet.raw(this.glyphs) : assert(glyphs.length == _abc123.length);

  AltGlyphSet(String glyphString)
    : this.raw(glyphString.characters.toList(growable: false));

  AltGlyphSet.onlyAlphabet(String glyphString)
    : this.raw(
        glyphString.characters.toList(growable: false) + "0123456789".split(""),
      );

  AltGlyphSet.onlyNumbers(String glyphString)
    : this.raw(
        "abcdefghijklmnopqrstuvwxyz".split("") +
            glyphString.characters.toList(growable: false),
      );

  AltGlyphSet removeNumbers() =>
      AltGlyphSet.onlyAlphabet(glyphs.sublist(0, 52).join());

  AltGlyphSet removeAlphabet() =>
      AltGlyphSet.onlyNumbers(glyphs.sublist(52).join());

  static final circledGlyphSet = AltGlyphSet(
    "ⒶⒷⒸⒹⒺⒻⒼⒽⒾⒿⓀⓁⓂⓃⓄⓅⓆⓇⓈⓉⓊⓋⓌⓍⓎⓏ"
    "ⓐⓑⓒⓓⓔⓕⓖⓗⓘⓙⓚⓛⓜⓝⓞⓟⓠⓡⓢⓣⓤⓥⓦⓧⓨⓩ"
    "①②③④⑤⑥⑦⑧⑨⑩",
  );

  static final boldGlyphSet = AltGlyphSet.onlyAlphabet(
    "𝗔𝗕𝗖𝗗𝗘𝗙𝗚𝗛𝗜𝗝𝗞𝗟𝗠𝗡𝗢𝗣𝗤𝗥𝗦𝗧𝗨𝗩𝗪𝗫𝗬𝗭"
    "𝗮𝗯𝗰𝗱𝗲𝗳𝗴𝗵𝗶𝗷𝗸𝗹𝗺𝗻𝗼𝗽𝗾𝗿𝘀𝘁𝘂𝘃𝘄𝘅𝘆𝘇",
  );

  static final boldItalicGlyphSet = AltGlyphSet.onlyAlphabet(
    "𝑨𝑩𝑪𝑫𝑬𝑭𝑮𝑯𝑰𝑱𝑲𝑳𝑴𝑵𝑶𝑷𝑸𝑹𝑺𝑻𝑼𝑽𝑾𝑿𝒀𝒁"
    "𝒂𝒃𝒄𝒅𝒆𝒇𝒈𝒉𝒊𝒋𝒌𝒍𝒎𝒏𝒐𝒑𝒒𝒓𝒔𝒕𝒖𝒗𝒘𝒙𝒚𝒛",
  );

  static final scriptGlyphSet = AltGlyphSet.onlyAlphabet(
    "𝒜ℬ𝒞𝒟ℰℱ𝒢ℋℐ𝒥𝒦ℒℳℕ𝒪𝒫𝒬ℛ𝒮𝒯𝒰𝒱𝒲𝒳𝒴𝒵"
    "𝒶𝒷𝒸𝒹ℯ𝒻𝑔ℎ𝒾𝒿𝓀𝓁𝓂𝓃ℴ𝓅𝓆𝓇𝓈𝓉𝓊𝓋𝓌𝓍𝓎𝓏",
  );

  static final frakturGlyphSet = AltGlyphSet.onlyAlphabet(
    "𝔄𝔅ℭ𝔇𝔈𝔉𝔊ℌℑ𝔍𝔎𝔏𝔐𝔑𝔒𝔓𝔔ℜ𝔖𝔗𝔘𝔙𝔚𝔛𝔜𝔝"
    "𝔞𝔟𝔠𝔡𝔢𝔣𝔤𝔥𝔦𝔧𝔨𝔩𝔪𝔫𝔬𝔭𝔮𝔯𝔰𝔱𝔲𝔳𝔴𝔵𝔶𝔷",
  );

  static final doubleStruckGlyphSet = AltGlyphSet.onlyAlphabet(
    "𝔸𝔹ℂ𝔻𝔼𝔽𝔾ℍ𝕀𝕁𝕂𝕃𝕄ℕ𝕆ℙℚℝ𝕊𝕋𝕌𝕍𝕎𝕏𝕐ℤ"
    "𝕒𝕓𝕔𝕕𝕖𝕗𝕘𝕙𝕚𝕛𝕜𝕝𝕞𝕟𝕠𝕡𝕢𝕣𝕤𝕥𝕦𝕧𝕨𝕩𝕪𝕫",
  );

  static final monospaceGlyphSet = AltGlyphSet.onlyAlphabet(
    "𝙰𝙱𝙲𝙳𝙴𝙵𝙶𝙷𝙸𝙹𝙺𝙻𝙼𝙽𝙾𝙿𝚀𝚁𝚂𝚃𝚄𝚅𝚆𝚇𝚈𝚉"
    "𝚊𝚋𝚌𝚍𝚎𝚏𝚐𝚑𝚒𝚓𝚔𝚕𝚖𝚗𝚘𝚙𝚚𝚛𝚜𝚝𝚞𝚟𝚠𝚡𝚢𝚣",
  );

  static final emojiGlyphSet = AltGlyphSet(
    "🅰️🅱️🅲🅳🅴🅵🅶🅷🅸🅹🅺🅻🅼🅽🅾️🅿️🆀🆁🆂🆃🆄🆅🆆🆇🆈🆉"
    "🅰️🅱️🅲🅳🅴🅵🅶🅷🅸🅹🅺🅻🅼🅽🅾️🅿️🆀🆁🆂🆃🆄🆅🆆🆇🆈🆉"
    "0️⃣1️⃣2️⃣3️⃣4️⃣5️⃣6️⃣7️⃣8️⃣9️⃣",
  );

  static final enclosedGlyphSet = AltGlyphSet(
    "🄰🄱🄲🄳🄴🄵🄶🄷🄸🄹🄺🄻🄼🄽🄾🄿🅀🅁🅂🅃🅄🅅🅆🅇🅈🅉"
    "🄰🄱🄲🄳🄴🄵🄶🄷🄸🄹🄺🄻🄼🄽🄾🄿🅀🅁🅂🅃🅄🅅🅆🅇🅈🅉"
    "⓪①②③④⑤⑥⑦⑧⑨",
  );

  // q does not exist
  static final superscriptGlyphSet = AltGlyphSet(
    "ᴬᴮᶜᴰᴱᶠᴳᴴᴵᴶᴷᴸᴹᴺᴼᴾQᴿˢᵀᵁⱽᵂXʸᶻ"
    "ᵃᵇᶜᵈᵉᶠᵍʰⁱʲᵏˡᵐⁿᵒᵖqʳˢᵗᵘᵛʷˣʸᶻ"
    "⁰¹²³⁴⁵⁶⁷⁸⁹",
  );

  // most letters don not exist
  static final subscriptGlyphSet = AltGlyphSet.onlyNumbers("₀₁₂₃₄₅₆₇₈₉");
}

class TextSpan {
  /// The text content of this span.
  final String text;

  /// The style applied to this text span
  /// and as base style of its children if it has any.
  final ForegroundStyle? style;

  /// The background color applied to this text span
  /// and as base style of its children if it has any.
  final Color? backgroundColor;

  /// Child text spans nested within this span.
  ///
  /// The children are always rendered with the style of this span
  /// as the base style.
  /// Further, the contents of the children are rendered after the content
  /// of this span.
  final List<TextSpan>? children;

  /// Creates a [TextSpan] with the given values.
  const TextSpan({
    this.text = "",
    this.style,
    this.backgroundColor,
    this.children,
  });
}

Color toStandard(Color color) => switch (color._type) {
  colorBrightType => _extendedColors[color._data],
  colorExtendedType => _extendedColors[_extendedToStandardIndex(color._data)],
  colorRgbType => _extendedColors[_rgbToExtendedIndex(color._data)],
  _ => color,
};

Color toAnsi(Color color) => switch (color._type) {
  colorExtendedType => _extendedColors[_extendedToAnsiIndex(color._data)],
  colorRgbType => _extendedColors[_rgbToExtendedIndex(color._data)],
  _ => color,
};

Color toExtended(Color color) => switch (color._type) {
  colorRgbType => _extendedColors[_rgbToExtendedIndex(color._data)],
  _ => color,
};

int getRgbVal(Color color) {
  if (color._type == 0) {
    return color._data;
  } else {
    return _extendedRgbValues[color._data];
  }
}

int colorData(Color color) => color._.data;

int colorTypeFromData(int colorData) => colorData & _colorTypeMask;
int standardIndexFromData(int colorData) => colorData & ~_colorTypeMask;
int brightIndexFromData(int colorData) => colorData & ~_colorTypeMask;
int extendedIndexFromData(int colorData) => colorData & ~_colorTypeMask;
int rgbFromData(int colorData) => colorData & ~_colorTypeMask;

const _colorTypeMask = 0xF << 24;
const colorNormalType = 1 << 24;
const colorStandardType = 1 << 25;
const colorBrightType = 1 << 26;
const colorExtendedType = 1 << 27;
const colorRgbType = 0;

String fgSgr(Color color) => color._.fgSgr;
String bgSgr(Color color) => color._.bgSgr;

/// more efficient equality check
bool equalsColor(Color a, Color b) => a._.data == b._.data;

bool equalsForeground(Foreground a, Foreground b) {
  if (a == 32 && b == 32 && a.effects._data == 0 && b.effects._data == 0) {
    return false; // TODO: maybe remove
  }
  return a.effects != b.effects &&
      a.codeUnit == b.codeUnit &&
      equalsColor(a.color, b.color);
}

int _rgb(int r, int g, int b) => r * 256 * 256 + g * 256 + b;
int _gray(int gray) => _rgb(gray, gray, gray);

List<Color> _extendedColors = [
  for (var i = 0; i < 8; i++) Color.standard(i),
  for (var i = 0; i < 8; i++) Color.bright(i),
  for (var i = 16; i <= 256; i++) Color.extended(i),
];

const _extendedColorsCubeSteps = [0, 95, 135, 175, 215, 255];

List<int> _extendedRgbValues = [
  _rgb(0, 0, 0), // 0 black
  _rgb(128, 0, 0), // 1 red
  _rgb(0, 128, 0), // 2 green
  _rgb(128, 128, 0), // 3 yellow
  _rgb(0, 0, 128), // 4 blue
  _rgb(128, 0, 128), // 5 magenta
  _rgb(0, 128, 128), // 6 cyan
  _rgb(192, 192, 192), // 7 white
  _rgb(128, 128, 128), // 8 bright black / gray
  _rgb(255, 0, 0), // 9 bright red
  _rgb(0, 255, 0), // 10 bright green
  _rgb(255, 255, 0), // 11 bright yellow
  _rgb(0, 0, 255), // 12 bright blue
  _rgb(255, 0, 255), // 13 bright magenta
  _rgb(0, 255, 255), // 14 bright cyan
  _rgb(255, 255, 255), // 15 bright white
  // 16–231: 6x6x6 color cube
  for (var r in _extendedColorsCubeSteps)
    for (var g in _extendedColorsCubeSteps)
      for (var b in _extendedColorsCubeSteps) _rgb(r, g, b),

  // 232–255: grayscale ramp
  for (int i = 0; i < 24; i++) _gray((8 + i * 10).clamp(0, 255)),
];

int _extendedToStandardIndex(int extendedIndex) {
  // First 16 colors map directly
  if (extendedIndex < 16) return extendedIndex;

  // 16–231: 6x6x6 cube
  if (extendedIndex <= 231) {
    // Convert cube index to RGB indices 0..5
    int i = extendedIndex - 16;
    int r = i ~/ 36;
    int g = (i % 36) ~/ 6;
    int b = i % 6;

    // Map to standard 16-color index
    int ansiIndex = 0;
    if (r > 2) ansiIndex |= 1 << 2; // red
    if (g > 2) ansiIndex |= 1 << 1; // green
    if (b > 2) ansiIndex |= 1 << 0; // blue

    // Bright bit for foreground? You can optionally set bright = 8
    return ansiIndex; // 0..7
  }

  // 232–255: grayscale ramp → map to either 7 (white) or 0 (black)
  return (extendedIndex - 232) > 11 ? 15 : 7;
}

int _extendedToAnsiIndex(int extendedIndex) {
  // First 16 colors map directly
  if (extendedIndex < 16) return extendedIndex;

  // 16–231: 6x6x6 cube
  if (extendedIndex <= 231) {
    int i = extendedIndex - 16;
    int r = i ~/ 36;
    int g = (i % 36) ~/ 6;
    int b = i % 6;

    int ansiIndex = 0;
    if (r > 2) ansiIndex |= 1 << 2; // red
    if (g > 2) ansiIndex |= 1 << 1; // green
    if (b > 2) ansiIndex |= 1 << 0; // blue

    // Bright bit if any channel is > 3 (upper half of cube)
    if (r > 2 || g > 2 || b > 2) ansiIndex |= 8;

    return ansiIndex; // 0–15
  }

  // 232–255: grayscale ramp → bright for light grays
  int gray = extendedIndex - 232;
  return gray > 11 ? 15 : 7; // 7=dark, 15=bright white
}

int _rgbToExtendedIndex(int rgb) {
  final r = (rgb ~/ 256 ~/ 256);
  final g = ((rgb % (256 * 256)) ~/ 256);
  final b = (rgb % 256);
  // Map RGB to 6x6x6 cube
  int rIndex = r < 48
      ? 0
      : r < 114
      ? 1
      : ((r - 35) ~/ 40);
  int gIndex = g < 48
      ? 0
      : g < 114
      ? 1
      : ((g - 35) ~/ 40);
  int bIndex = b < 48
      ? 0
      : b < 114
      ? 1
      : ((b - 35) ~/ 40);

  int cubeIndex = 16 + 36 * rIndex + 6 * gIndex + bIndex;

  // Cube RGB values
  const cubeSteps = [0, 95, 135, 175, 215, 255];
  int rCube = cubeSteps[rIndex];
  int gCube = cubeSteps[gIndex];
  int bCube = cubeSteps[bIndex];
  int distCube =
      (r - rCube) * (r - rCube) +
      (g - gCube) * (g - gCube) +
      (b - bCube) * (b - bCube);

  // 2️⃣ Grayscale (232–255)
  int gray = ((r + g + b) ~/ 3).clamp(0, 255);
  int grayIndex = ((gray - 8) / 10.7).round().clamp(0, 23);
  int grayXterm = 232 + grayIndex;
  int grayVal = (8 + grayIndex * 10.7).round();
  int distGray =
      (r - grayVal) * (r - grayVal) +
      (g - grayVal) * (g - grayVal) +
      (b - grayVal) * (b - grayVal);

  // 3️⃣ Pick closest
  return distGray < distCube ? grayXterm : cubeIndex;
}

int textEffectsData(TextEffects effects) => effects._data;
TextEffects textEffectsFromData(int data) => TextEffects._(data);

extension ToDebugStringColor on Color {
  String toDebugString() {
    switch (_type) {
      case colorNormalType:
        return "normal";
      case colorStandardType:
        return "standard(${_data})";
      case colorBrightType:
        return "bright(${_data & 0x7F_FF_FF_FF_FF_FF_FF})";
      case colorExtendedType:
        return "extended(${_data & 0x7F_FF_FF_FF_FF_FF_FF})";
      case colorRgbType:
        final r = _data ~/ 256 ~/ 256;
        final g = (_data % (256 * 256)) ~/ 256;
        final b = _data % 256;
        return "rgb($r, $g, $b)";
      default:
        return "unknown";
    }
  }
}

extension ToDebugStringTextEffects on TextEffects {
  String toDebugString() {
    if (isEmpty) return "none";
    List<String> effects = [];
    for (final effect in TextEffect.values) {
      if (effect.containedIn(this)) {
        effects.add(effect.name);
      }
    }
    return effects.join(", ");
  }
}

extension ToDebugStringForegroundStyle on ForegroundStyle {
  String toDebugString() {
    List<String> parts = [];
    if (color._type != 0 || color._data != 0) {
      parts.add("color: ${color.toDebugString()}");
    }
    if (!effects.isEmpty) {
      parts.add("effects: ${effects.toDebugString()}");
    }
    return parts.join(", ");
  }
}

extension ToDebugStringForeground on Foreground {
  String toDebugString() {
    List<String> parts = [];
    if (codeUnit != 32) {
      parts.add("codePoint: $codeUnit");
    }
    final styleDetail = style.toDebugString();
    if (styleDetail.isNotEmpty) {
      parts.add("style: {$styleDetail}");
    }
    return parts.join(", ");
  }
}
