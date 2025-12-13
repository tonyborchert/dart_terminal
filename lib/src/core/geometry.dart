// Dart imports:
import 'dart:math' as math;

/// Represents a two-dimensional size with integer width and height.
///
/// Used for specifying dimensions of terminal UI elements.
extension type const Size._(({int width, int height}) _) {
  /// Creates a new Size with the specified [width] and [height].
  const Size(int width, int height) : this._((width: width, height: height));

  /// The horizontal extent of this size.
  int get width => _.width;

  /// The vertical extent of this size.
  int get height => _.height;

  /// The area covered by this size ([width] * [height]).
  int get area => width * height;
}

/// Represents a 2D vector offset with integer components.
///
/// Used for relative movements and position calculations in the terminal.
///
/// For example, an Offset of (2, -1) represents a movement 2 units to the right
/// and 1 unit up.
extension type const Offset._(({int dx, int dy}) _) {
  /// Creates a new Offset with the specified horizontal ([dx]) and vertical ([dy]) deltas.
  const Offset(int dx, int dy) : this._((dx: dx, dy: dy));

  /// A zero offset, representing no displacement.
  static const Offset zero = Offset(0, 0);

  /// The horizontal component of this offset.
  int get dx => _.dx;

  /// The vertical component of this offset.
  int get dy => _.dy;

  Offset operator *(int factor) =>
      Offset._((dx: _.dx * factor, dy: _.dy * factor));

  Offset operator -() => this * -1;
}

const e1 = Offset(1, 0);
const e2 = Offset(0, 1);

/// Represents an absolute position in the terminal with integer coordinates.
///
/// The coordinate system starts from the top-left corner (0,0) and increases
/// right and down.
extension type const Position._(({int x, int y}) _) {
  /// Creates a new Position at the specified coordinates ([x], [y]).
  const Position(int x, int y) : this._((x: x, y: y));

  /// The origin position (0,0), representing the top-left corner.
  static const Position topLeft = Position(0, 0);

  /// Creates a [Rect] from this position and the given [size].
  ///
  /// The position becomes the top-left corner of the rectangle.
  Rect operator &(Size size) =>
      Rect(x, x + size.width - 1, y, y + size.height - 1);

  /// Translates this position by the given offset.
  ///
  /// Returns a new position offset by [v].
  Position operator +(Offset v) => Position(x + v.dx, y + v.dy);

  /// Translates this position by the given offset.
  ///
  /// Returns a new position offset by -[v].
  Position operator -(Offset v) => Position(x - v.dx, y - v.dy);

  /// The horizontal coordinate of this position.
  int get x => _.x;

  /// The vertical coordinate of this position.
  int get y => _.y;

  /// Clamps this position within the bounds of the given rectangle [rect].
  Position clamp(Rect rect) => Position(
    math.max(rect.x1, math.min(x, rect.x2)),
    math.max(rect.y1, math.min(y, rect.y2)),
  );
}

/// Represents a rectangular area in the terminal.
///
/// The rectangle is defined by its top-left and bottom-right corners,
/// using inclusive coordinates.
extension type const Rect._(({int x1, int x2, int y1, int y2}) _) {
  /// Creates a new Rect from the specified coordinates.
  ///
  /// [x1] and [y1] define the top-left corner.
  /// [x2] and [y2] define the bottom-right corner (inclusive).
  const Rect(int x1, int x2, int y1, int y2)
    : this._((x1: x1, x2: x2, y1: y1, y2: y2));

  /// The width of the rectangle (inclusive).
  int get width => _.x2 - _.x1 + 1;

  /// The height of the rectangle (inclusive).
  int get height => _.y2 - _.y1 + 1;

  /// The size of this rectangle as a [Size] object.
  Size get size => Size(width, height);

  /// The x-coordinate of the left edge.
  int get x1 => _.x1;

  /// The x-coordinate of the right edge.
  int get x2 => _.x2;

  /// The y-coordinate of the top edge.
  int get y1 => _.y1;

  /// The y-coordinate of the bottom edge.
  int get y2 => _.y2;

  /// The position of the top-left corner.
  Position get topLeft => Position(x1, y1);

  /// The position of the top-right corner.
  Position get topRight => Position(x2, y1);

  /// The position of the bottom-right corner.
  Position get bottomRight => Position(x2, y2);

  /// The position of the bottom-left corner.
  Position get bottomLeft => Position(x1, y2);

  /// Returns a new rectangle that is the intersection of this rectangle and [clip].
  ///
  /// The resulting rectangle is guaranteed to fit within both rectangles.
  Rect clip(Rect clip) => Rect(
    math.max(_.x1, clip.x1),
    math.min(_.x2, clip.x2),
    math.max(_.y1, clip.y1),
    math.min(_.y2, clip.y2),
  );

  /// Checks if the given [position] lies within this rectangle.
  bool contains(Position position) =>
      _.x1 <= position.x &&
      _.x2 >= position.x &&
      _.y1 <= position.y &&
      _.y2 >= position.y;

  /// Checks if the given [rect] lies within this rectangle.
  bool containsRect(Rect rect) =>
      contains(rect.topLeft) && contains(rect.bottomRight);
}
