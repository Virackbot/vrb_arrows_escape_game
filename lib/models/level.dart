/// Directions an arrow can point, plus a sentinel for cells with no arrow
/// (e.g. the exit cell).
enum ArrowDirection { up, down, left, right, none }

/// The four sides of a cell that can carry a wall segment.
enum Wall { north, south, east, west }

/// A 2-D grid coordinate.
class Position {
  final int row;
  final int col;

  const Position(this.row, this.col);

  /// Returns the neighbour reached by moving one step in [dir].
  Position move(ArrowDirection dir) {
    switch (dir) {
      case ArrowDirection.up:
        return Position(row - 1, col);
      case ArrowDirection.down:
        return Position(row + 1, col);
      case ArrowDirection.left:
        return Position(row, col - 1);
      case ArrowDirection.right:
        return Position(row, col + 1);
      case ArrowDirection.none:
        return this;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is Position && other.row == row && other.col == col;

  @override
  int get hashCode => Object.hash(row, col);

  @override
  String toString() => '($row,$col)';
}

/// All data needed to render and play a single puzzle level.
class Level {
  /// Monotonically increasing level number used as the RNG seed.
  final int levelNumber;

  final int rows;
  final int cols;

  /// Arrow direction assigned to every cell.
  /// [ArrowDirection.none] means "no arrow" (used for the exit cell and
  /// solid/unreachable cells).
  final List<List<ArrowDirection>> grid;

  /// For each cell, the set of sides that carry a wall segment.
  /// Solid (unreachable) cells have all four walls; open corridor cells only
  /// carry walls on sides that are not shared with another open cell.
  final List<List<Set<Wall>>> walls;

  /// Starting cell where the player begins dragging.
  final Position start;

  /// Exit cell the player must reach to win.
  final Position exit;

  /// The unique correct path from [start] to [exit].
  final List<Position> solutionPath;

  /// Normalised difficulty in [0, 1]; increases with level number.
  final double difficultyRating;

  const Level({
    required this.levelNumber,
    required this.rows,
    required this.cols,
    required this.grid,
    required this.walls,
    required this.start,
    required this.exit,
    required this.solutionPath,
    required this.difficultyRating,
  });
}
