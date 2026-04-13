import 'dart:math';
import '../models/level.dart';

/// Procedurally generates [Level] objects from a level number.
///
/// The same level number always produces the same maze because [Random] is
/// seeded with `levelNumber * [_seedMultiplier]`.
///
/// Generation algorithm (inverse / guaranteed-solvable):
///   1. Pick a random start cell on the grid edge.
///   2. Perform a seeded random walk to build a non-self-intersecting
///      *solution path* of appropriate length.
///   3. Grow several *branch corridors* off the solution path to create
///      dead-ends and visual complexity.
///   4. Assign arrows: solution-path cells point toward the next cell;
///      branch cells point *away* from the solution path (dead ends).
///   5. Build the wall map: a wall segment exists on every side of an open
///      cell that is not shared with another open cell.
class LevelGenerator {
  // ── tuneable constants ────────────────────────────────────────────────────

  /// Multiplier applied to the level number to spread RNG seeds far apart so
  /// consecutive levels produce visually distinct mazes.
  static const int _seedMultiplier = 31337;

  static const int _maxGenerationAttempts = 150;
  static const int _minAbsolutePathLength = 4;
  static const double _pathBaseRatio = 0.30;
  static const double _difficultyPathBonus = 0.42;
  static const double _maxPathRatio = 0.86;

  // ── public API ────────────────────────────────────────────────────────────

  /// Returns a fully solvable [Level] for [levelNumber].
  static Level generateLevel(int levelNumber) {
    final random = Random(levelNumber * _seedMultiplier);

    final (rows, cols) = _gridSize(levelNumber, random);
    final difficulty = _difficulty(levelNumber);

    // Retry until we get a path long enough to be interesting.
    List<Position> solutionPath = const [];
    Position start = const Position(0, 0);
    Position exit = const Position(0, 0);

    for (int attempt = 0;
        attempt < _maxGenerationAttempts && solutionPath.length < _minAbsolutePathLength;
        attempt++) {
      final r = _buildSolutionPath(rows, cols, random, difficulty);
      solutionPath = r.$1;
      start = r.$2;
      exit = r.$3;
    }

    // Grow dead-end branch corridors for visual interest.
    final branches = _buildBranches(rows, cols, solutionPath, random, difficulty);

    // All cells that belong to some open corridor.
    final openCells = <Position>{...solutionPath, ...branches.expand((b) => b)};

    final grid = _buildGrid(rows, cols, solutionPath, exit, branches, openCells, random);
    final walls = _buildWalls(rows, cols, openCells);

    return Level(
      levelNumber: levelNumber,
      rows: rows,
      cols: cols,
      grid: grid,
      walls: walls,
      start: start,
      exit: exit,
      solutionPath: solutionPath,
      difficultyRating: difficulty,
    );
  }

  // ── private helpers ───────────────────────────────────────────────────────

  /// Grid size based on level band.
  static (int, int) _gridSize(int level, Random rng) {
    final int size;
    if (level <= 100) {
      size = 7 + rng.nextInt(3); // 7–9
    } else if (level <= 500) {
      size = 10 + rng.nextInt(3); // 10–12
    } else if (level <= 2000) {
      size = 12 + rng.nextInt(3); // 12–14
    } else {
      size = 14 + rng.nextInt(3); // 14–16
    }
    return (size, size);
  }

  /// Normalised difficulty in [0, 1].
  static double _difficulty(int level) {
    if (level <= 100) return level / 100.0 * 0.20;
    if (level <= 500) return 0.20 + (level - 100) / 400.0 * 0.30;
    if (level <= 2000) return 0.50 + (level - 500) / 1500.0 * 0.30;
    return 0.80 + min((level - 2000) / 8000.0 * 0.20, 0.20);
  }

  /// Random-walk to produce the solution path.
  static (List<Position>, Position, Position) _buildSolutionPath(
      int rows, int cols, Random rng, double difficulty) {
    // Choose start on an edge.
    final edge = rng.nextInt(4);
    final Position start;
    switch (edge) {
      case 0:
        start = Position(0, rng.nextInt(cols));
        break;
      case 1:
        start = Position(rows - 1, rng.nextInt(cols));
        break;
      case 2:
        start = Position(rng.nextInt(rows), 0);
        break;
      default:
        start = Position(rng.nextInt(rows), cols - 1);
    }

    final minLen = max(
      _minAbsolutePathLength,
      (rows * cols * (_pathBaseRatio + difficulty * _difficultyPathBonus)).round(),
    );
    final maxLen = (rows * cols * _maxPathRatio).round();

    final visited = <Position>{start};
    final path = <Position>[start];
    var current = start;

    final dirs = <ArrowDirection>[
      ArrowDirection.up,
      ArrowDirection.down,
      ArrowDirection.left,
      ArrowDirection.right,
    ];

    while (path.length < maxLen) {
      dirs.shuffle(rng);
      bool moved = false;
      for (final d in dirs) {
        final next = current.move(d);
        if (_inBounds(next, rows, cols) && !visited.contains(next)) {
          visited.add(next);
          path.add(next);
          current = next;
          moved = true;
          break;
        }
      }
      if (!moved) break;

      if (path.length >= minLen) {
        final stopChance = difficulty < 0.5 ? 0.07 : 0.025;
        if (rng.nextDouble() < stopChance) break;
      }
    }

    if (path.length < _minAbsolutePathLength) return (const [], start, start);
    return (path, start, path.last);
  }

  /// Grow branch dead-end corridors off the solution path.
  /// More branches at higher difficulties to increase visual complexity.
  static List<List<Position>> _buildBranches(
    int rows,
    int cols,
    List<Position> solutionPath,
    Random rng,
    double difficulty,
  ) {
    final pathSet = solutionPath.toSet();
    final allOpen = pathSet.toSet();
    final branches = <List<Position>>[];

    // Number of branches scales with difficulty.
    final branchCount = (rows * cols * (0.05 + difficulty * 0.20)).round().clamp(2, 30);
    final maxBranchLen = max(2, (rows * 0.4).round());

    for (int b = 0; b < branchCount; b++) {
      // Pick a random cell on the solution path as the branch root.
      final root = solutionPath[rng.nextInt(solutionPath.length)];
      final branch = <Position>[root];
      var current = root;

      for (int step = 0; step < maxBranchLen; step++) {
        final dirs = <ArrowDirection>[
          ArrowDirection.up,
          ArrowDirection.down,
          ArrowDirection.left,
          ArrowDirection.right,
        ]..shuffle(rng);
        bool moved = false;
        for (final d in dirs) {
          final next = current.move(d);
          if (_inBounds(next, rows, cols) && !allOpen.contains(next)) {
            allOpen.add(next);
            branch.add(next);
            current = next;
            moved = true;
            break;
          }
        }
        if (!moved) break;
      }

      if (branch.length > 1) branches.add(branch);
    }

    return branches;
  }

  /// Build the arrow grid.
  ///
  /// * Solution-path cells point toward their successor.
  /// * Branch cells point toward the branch root (i.e. into the dead end,
  ///   misleading the player).
  /// * The exit cell and solid cells have [ArrowDirection.none].
  static List<List<ArrowDirection>> _buildGrid(
    int rows,
    int cols,
    List<Position> solutionPath,
    Position exit,
    List<List<Position>> branches,
    Set<Position> openCells,
    Random rng,
  ) {
    final grid = List.generate(
        rows, (_) => List.filled(cols, ArrowDirection.none));

    // Solution path arrows.
    for (int i = 0; i < solutionPath.length - 1; i++) {
      final from = solutionPath[i];
      grid[from.row][from.col] = _dirBetween(from, solutionPath[i + 1]);
    }
    // Exit cell has no arrow.
    grid[exit.row][exit.col] = ArrowDirection.none;

    // Branch arrows: every cell points toward the cell before it in the branch
    // (i.e. back toward the solution path — a dead end for the player who
    // enters the branch).
    for (final branch in branches) {
      for (int i = branch.length - 1; i >= 1; i--) {
        final cell = branch[i];
        final prev = branch[i - 1];
        // Only assign if not already set by solution path.
        if (grid[cell.row][cell.col] == ArrowDirection.none) {
          grid[cell.row][cell.col] = _dirBetween(cell, prev);
        }
      }
    }

    return grid;
  }

  /// Build the wall map.
  ///
  /// A wall exists on each side of an open cell that is not shared with
  /// another open cell.  Solid (non-open) cells carry walls on all four sides.
  static List<List<Set<Wall>>> _buildWalls(
      int rows, int cols, Set<Position> openCells) {
    return List.generate(rows, (r) {
      return List.generate(cols, (c) {
        final pos = Position(r, c);
        if (!openCells.contains(pos)) {
          return {Wall.north, Wall.south, Wall.east, Wall.west};
        }
        final w = <Wall>{};
        if (r == 0 || !openCells.contains(Position(r - 1, c))) w.add(Wall.north);
        if (r == rows - 1 || !openCells.contains(Position(r + 1, c))) w.add(Wall.south);
        if (c == 0 || !openCells.contains(Position(r, c - 1))) w.add(Wall.west);
        if (c == cols - 1 || !openCells.contains(Position(r, c + 1))) w.add(Wall.east);
        return w;
      });
    });
  }

  static bool _inBounds(Position p, int rows, int cols) =>
      p.row >= 0 && p.row < rows && p.col >= 0 && p.col < cols;

  static ArrowDirection _dirBetween(Position from, Position to) {
    if (to.row < from.row) return ArrowDirection.up;
    if (to.row > from.row) return ArrowDirection.down;
    if (to.col < from.col) return ArrowDirection.left;
    return ArrowDirection.right;
  }
}
