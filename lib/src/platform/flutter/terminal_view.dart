// Dart imports:
import 'dart:ui';

// Flutter imports:
import 'package:flutter/material.dart' as flutter;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

// Project imports:
import 'package:dart_terminal/core.dart' as term;
import 'package:dart_terminal/core.dart' hide Offset, Color, Colors, Rect, Size;
import '../../core/style.dart' as s;
import '../shared/buffer_viewport.dart';
import 'hashing.dart';
import 'viewport.dart';
import 'gesture_handling.dart';
import 'keyboard_handling.dart';
import 'paint_util.dart';

class TerminalView extends StatefulWidget {
  const TerminalView({
    super.key,
    this.textScaler,
    this.autofocus = true,
    this.focusNode,
    required this.terminalListener,
    required this.terminalViewport,
  });

  final FocusNode? focusNode;
  final TextScaler? textScaler;

  /// True if this widget will be selected as the initial focus when no other
  /// node in its scope is currently focused.
  final bool autofocus;

  final TerminalListener terminalListener;
  final FlutterTerminalViewport terminalViewport;

  @override
  State<TerminalView> createState() => TerminalViewState();
}

class TerminalViewState extends State<TerminalView> {
  late FocusNode _focusNode;

  final _viewportKey = GlobalKey();

  // String? _composingText;

  RenderTerminal get renderTerminal =>
      _viewportKey.currentContext!.findRenderObject() as RenderTerminal;

  @override
  void initState() {
    _focusNode = widget.focusNode ?? FocusNode();
    super.initState();
  }

  @override
  void didUpdateWidget(TerminalView oldWidget) {
    if (oldWidget.focusNode != widget.focusNode) {
      if (oldWidget.focusNode == null) {
        _focusNode.dispose();
      }
      _focusNode = widget.focusNode ?? FocusNode();
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget child = _TerminalView(
      key: _viewportKey,
      padding: MediaQuery.of(context).padding,
      textScaler: widget.textScaler ?? MediaQuery.textScalerOf(context),
      focusNode: _focusNode,
      terminalListener: widget.terminalListener,
      terminalViewport: widget.terminalViewport,
    );

    child = TerminalScrollGestureHandler(
      getCellOffset: (offset) => renderTerminal.getCellOffset(offset),
      getLineHeight: () => renderTerminal.lineHeight,
      terminalListener: widget.terminalListener,
      child: child,
    );

    // Only listen for key input from a hardware keyboard.
    child = CustomKeyboardListener(
      child: child,
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      terminalListener: widget.terminalListener,
    );

    child = TerminalGestureHandler(terminalView: this, child: child);

    child = Container(color: Colors.black, child: child);

    return child;
  }

  Rect get cursorRect {
    return renderTerminal.cursorOffset & renderTerminal.cellSize;
  }

  Rect get globalCursorRect {
    return renderTerminal.localToGlobal(renderTerminal.cursorOffset) &
        renderTerminal.cellSize;
  }
}

class _TerminalView extends LeafRenderObjectWidget {
  const _TerminalView({
    super.key,
    required this.padding,
    required this.textScaler,
    required this.focusNode,
    required this.terminalListener,
    required this.terminalViewport,
  });

  final EdgeInsets padding;

  final TextScaler textScaler;

  final FocusNode focusNode;

  final TerminalListener terminalListener;
  final FlutterTerminalViewport terminalViewport;

  @override
  RenderTerminal createRenderObject(BuildContext context) {
    return RenderTerminal(
      padding: padding,
      textScaler: textScaler,
      focusNode: focusNode,
      terminalListener: terminalListener,
      terminalViewport: terminalViewport,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderTerminal renderObject) {
    renderObject
      ..padding = padding
      ..textScaler = textScaler
      ..focusNode = focusNode;
  }
}

typedef EditableRectCallback = void Function(Rect rect, Rect caretRect);

class RenderTerminal extends RenderBox with RelayoutWhenSystemFontsChangeMixin {
  RenderTerminal({
    required EdgeInsets padding,
    required TextScaler textScaler,
    required FocusNode focusNode,
    required this.terminalListener,
    required this.terminalViewport,
  }) : _padding = padding,
       _focusNode = focusNode,
       _painter = TerminalPainter(textScaler: textScaler);

  final FlutterTerminalViewport terminalViewport;
  final TerminalListener terminalListener;

  EdgeInsets _padding;
  set padding(EdgeInsets value) {
    if (value == _padding) return;
    _padding = value;
    markNeedsLayout();
  }

  set textScaler(TextScaler value) {
    if (value == _painter.textScaler) return;
    _painter.textScaler = value;
    markNeedsLayout();
  }

  FocusNode _focusNode;
  set focusNode(FocusNode value) {
    if (value == _focusNode) return;
    if (attached) _focusNode.removeListener(_onFocusChange);
    _focusNode = value;
    if (attached) _focusNode.addListener(_onFocusChange);
    markNeedsPaint();
  }

  term.Size? _viewportSize;

  final TerminalPainter _painter;

  void _onFocusChange() {
    markNeedsPaint();
  }

  @override
  final isRepaintBoundary = true;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _focusNode.addListener(_onFocusChange);
    terminalViewport.onChanged = markNeedsPaint;
  }

  @override
  void detach() {
    super.detach();
    _focusNode.removeListener(_onFocusChange);
  }

  @override
  bool hitTestSelf(Offset position) {
    return true;
  }

  @override
  void systemFontsDidChange() {
    _painter.clearFontCache();
    super.systemFontsDidChange();
  }

  @override
  void performLayout() {
    size = constraints.biggest;

    _updateViewportSize();
  }

  /// The height of a terminal line in pixels. This includes the line spacing.
  /// Height of the entire terminal is expected to be a multiple of this value.
  double get lineHeight => _painter.cellSize.height;

  /// Get the top-left corner of the cell at [cellOffset] in pixels.
  Offset getOffset(Position cellOffset) {
    final row = cellOffset.y;
    final col = cellOffset.x;
    final x = col * _painter.cellSize.width;
    final y = row * _painter.cellSize.height;
    return Offset(x + _padding.left, y + _padding.top);
  }

  /// Get the [CellOffset] of the cell that [offset] is in.
  Position getCellOffset(Offset offset) {
    // TODO: CellOffset = Position beide fangen mit 0,0 an
    final x = offset.dx - _padding.left;
    final y = offset.dy - _padding.top;
    final row = y ~/ _painter.cellSize.height;
    final col = x ~/ _painter.cellSize.width;
    return Position(
      col.clamp(0, terminalViewport.size.width - 1),
      row.clamp(0, terminalViewport.size.height - 1),
    );
  }

  /// Send a mouse event at [offset] with [button] being currently in [buttonState].
  void mouseEvent(
    MouseButton button,
    MouseButtonState buttonState,
    Offset offset,
  ) {
    final position = getCellOffset(offset);
    terminalListener.mouseEvent(
      MousePressEvent(false, false, false, position, button, buttonState),
    );
  }

  /// Update the viewport size in cells based on the current widget size in
  /// pixels.
  void _updateViewportSize() {
    if (size <= _painter.cellSize) {
      return;
    }

    final viewportSize = term.Size(
      size.width ~/ _painter.cellSize.width,
      _viewportHeight ~/ _painter.cellSize.height,
    );

    if (_viewportSize != viewportSize) {
      _viewportSize = viewportSize;
      _resizeTerminalIfNeeded();
    }
  }

  /// Notify the underlying terminal that the viewport size has changed.
  void _resizeTerminalIfNeeded() {
    if (_viewportSize != null) {
      terminalViewport.updateSize(_viewportSize!);
      terminalListener.screenResize(_viewportSize!);
    }
  }

  bool get _shouldShowCursor {
    return terminalViewport.cursor != null;
  }

  double get _viewportHeight {
    return size.height - _padding.vertical;
  }

  /// The offset of the cursor from the top left corner of this render object.
  Offset get cursorOffset {
    return Offset(
      terminalViewport.cursor!.position.x * _painter.cellSize.width,
      terminalViewport.cursor!.position.y * _painter.cellSize.height,
    );
  }

  Size get cellSize {
    return _painter.cellSize;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!terminalViewport.hasSize) terminalViewport.updateSize(_viewportSize!);
    _paint(context, offset);
    context.setWillChangeHint();
  }

  void _paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;

    final rows = terminalViewport.size.height;
    final charHeight = _painter.cellSize.height;

    final firstLineOffset = 0 - _padding.top;
    final lastLineOffset = size.height + _padding.bottom;

    final firstLine = firstLineOffset ~/ charHeight;
    final lastLine = lastLineOffset ~/ charHeight;

    final effectFirstLine = firstLine.clamp(0, rows - 1);
    final effectLastLine = lastLine.clamp(0, rows - 1);

    for (var i = effectFirstLine; i <= effectLastLine; i++) {
      _painter.paintRow(
        canvas,
        offset.translate(0, (i * charHeight).truncateToDouble()),
        terminalViewport.getRow(i),
      );
    }

    if (_shouldShowCursor) {
      _painter.paintCursor(
        canvas,
        offset + cursorOffset,
        cursorType: terminalViewport.cursor!.type,
        hasFocus: _focusNode.hasFocus,
        doubleWidth: terminalViewport.cursorOnDoubleWidth,
      );
    }
  }
}

/// Encapsulates the logic for painting various terminal elements.
class TerminalPainter {
  TerminalPainter({required TextScaler textScaler}) : _textScaler = textScaler;

  /// A lookup table from terminal colors to Flutter colors.
  late var _colorPalette = PaletteBuilder(defaultTheme).build();

  /// Size of each character in the terminal.
  late var _cellSize = _measureCharSize();

  /// The cached for cells in the terminal. Should be cleared when the same
  /// cell no longer produces the same visual output. For example, when
  /// [_textStyle] is changed, or when the system font changes.
  final _paragraphCache = ParagraphCache(10240);

  TerminalStyle get textStyle => _textStyle;
  TerminalStyle _textStyle = TerminalStyle();
  set textStyle(TerminalStyle value) {
    if (value == _textStyle) return;
    _textStyle = value;
    _cellSize = _measureCharSize();
    _paragraphCache.clear();
  }

  TextScaler get textScaler => _textScaler;
  TextScaler _textScaler = TextScaler.linear(1.0);
  set textScaler(TextScaler value) {
    if (value == _textScaler) return;
    _textScaler = value;
    _cellSize = _measureCharSize();
    _paragraphCache.clear();
  }

  TerminalTheme get theme => _theme;
  TerminalTheme _theme = defaultTheme;
  set theme(TerminalTheme value) {
    if (value == _theme) return;
    _theme = value;
    _colorPalette = PaletteBuilder(value).build();
    _paragraphCache.clear();
  }

  Size _measureCharSize() {
    const test = 'mmmmmmmmmm';

    final textStyle = _textStyle.toTextStyle();
    final builder = ParagraphBuilder(textStyle.getParagraphStyle());
    builder.pushStyle(textStyle.getTextStyle(textScaler: _textScaler));
    builder.addText(test);

    final paragraph = builder.build();
    paragraph.layout(ParagraphConstraints(width: double.infinity));

    final result = Size(
      paragraph.maxIntrinsicWidth / test.length,
      paragraph.height,
    );

    paragraph.dispose();
    return result;
  }

  /// The size of each character in the terminal.
  Size get cellSize => _cellSize;

  /// When the set of font available to the system changes, call this method to
  /// clear cached state related to font rendering.
  void clearFontCache() {
    _cellSize = _measureCharSize();
    _paragraphCache.clear();
  }

  /// Paints the cursor based on the current cursor type.
  void paintCursor(
    Canvas canvas,
    Offset offset, {
    required CursorType cursorType,
    required bool doubleWidth,
    bool hasFocus = true,
  }) {
    final paint = Paint()
      ..color = _theme.cursor
      ..strokeWidth = 1;

    if (!hasFocus) {
      paint.style = PaintingStyle.stroke;
      canvas.drawRect(offset & _cellSize, paint);
      return;
    }

    switch (cursorType) {
      case CursorType.block:
        paint.style = PaintingStyle.fill;
        canvas.drawRect(offset & _cellSize, paint);
        return;
      case CursorType.underline:
        return canvas.drawLine(
          Offset(offset.dx, offset.dy + _cellSize.height - 1),
          Offset(offset.dx + _cellSize.width, offset.dy + _cellSize.height - 1),
          paint,
        );
      case CursorType.verticalBar:
        return canvas.drawLine(
          Offset(offset.dx, offset.dy + 0),
          Offset(offset.dx, offset.dy + _cellSize.height),
          paint,
        );
    }
  }

  /// Paints [row] to [canvas] at [offset]. The x offset of [offset] is usually
  /// 0, and the y offset is the top of the line.
  void paintRow(Canvas canvas, Offset offset, List<TerminalCell> row) {
    final cellWidth = _cellSize.width;

    for (var i = 0; i < row.length; i++) {
      final cell = row[i];
      final cellOffset = offset.translate(i * cellWidth, 0);

      paintCell(canvas, cellOffset, cell);

      // TODO
      // if (charWidth == 2) {
      //   i++;
      // }
    }
  }

  @pragma('vm:prefer-inline')
  void paintCell(Canvas canvas, Offset offset, TerminalCell cell) {
    if (cell.fg == graphemeCodeUnit) return;
    late final String grapheme;
    bool doubleWidth = false;
    if (cell.grapheme != null) {
      if (cell.grapheme!.isSecond) return;
      doubleWidth = cell.grapheme!.width == 2;
      grapheme = cell.grapheme!.data;
    } else {
      grapheme = String.fromCharCode(cell.fg.codeUnit);
    }
    paintCellBackground(canvas, offset, cell.bg, doubleWidth: doubleWidth);
    paintCellForeground(
      canvas,
      offset,
      grapheme,
      cell.fg.color,
      cell.fg.effects,
    );
  }

  /// Paints the character in the cell represented by [cellData] to [canvas] at
  /// [offset].
  @pragma('vm:prefer-inline')
  void paintCellForeground(
    Canvas canvas,
    Offset offset,
    String grapheme,
    s.Color color,
    s.TextEffects textEffects,
  ) {
    final colorData = s.colorData(color);
    final cacheKey =
        hashValues(grapheme, color, textEffects) ^ _textScaler.hashCode;
    var paragraph = _paragraphCache.getLayoutFromCache(cacheKey);

    if (paragraph == null) {
      // TODO: handle possibility that not exactly the same
      Color color = resolveColor(colorData);

      if (s.TextEffect.faint.containedIn(textEffects)) {
        color = color.withValues(alpha: 0.5);
      }

      final style = _textStyle.toTextStyle(
        color: color,
        bold: s.TextEffect.intense.containedIn(textEffects),
        italic: s.TextEffect.italic.containedIn(textEffects),
        underline: s.TextEffect.underline.containedIn(textEffects),
      );

      // Flutter does not draw an underline below a space which is not between
      // other regular characters. As only single characters are drawn, this
      // will never produce an underline below a space in the terminal. As a
      // workaround the regular space CodePoint 0x20 is replaced with
      // the CodePoint 0xA0. This is a non breaking space and a underline can be
      // drawn below it.
      if (s.TextEffect.underline.containedIn(textEffects) && grapheme == " ") {
        grapheme = String.fromCharCode(0xA0);
      }

      paragraph = _paragraphCache.performAndCacheLayout(
        grapheme,
        style,
        _textScaler,
        cacheKey,
      );
    }

    canvas.drawParagraph(paragraph, offset);
  }

  /// Paints the background of a cell represented by [contentData] to [canvas] at
  /// [offset].
  @pragma('vm:prefer-inline')
  void paintCellBackground(
    Canvas canvas,
    Offset offset,
    s.Color sColor, {
    bool doubleWidth = false,
  }) {
    final colorData = s.colorData(sColor);
    final colorType = s.colorTypeFromData(colorData);
    if (colorType == s.colorNormalType) return;
    final color = resolveColor(colorData);

    final paint = Paint()..color = color;
    final widthScale = doubleWidth ? 2 : 1;
    final size = Size(_cellSize.width * widthScale + 1, _cellSize.height);
    canvas.drawRect(offset & size, paint);
  }

  /// Get the effective color for a cell from information encoded in
  /// [colorData].
  @pragma('vm:prefer-inline')
  flutter.Color resolveColor(int colorData) {
    final colorType = s.colorTypeFromData(colorData);

    switch (colorType) {
      case s.colorNormalType:
        return _theme.foreground;
      case s.colorStandardType:
        return _colorPalette[s.standardIndexFromData(colorData)];
      case s.colorBrightType:
        return _colorPalette[s.brightIndexFromData(colorData) + 1];
      case s.colorExtendedType:
        return _colorPalette[s.extendedIndexFromData(colorData)];
      default:
        return flutter.Color(s.rgbFromData(colorData) | 0xFF000000);
    }
  }
}
