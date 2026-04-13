import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/level.dart';
import '../generators/level_generator.dart';

// ── Current level ─────────────────────────────────────────────────────────────

final currentLevelNumberProvider = StateProvider<int>((ref) => 1);

/// Derives the [Level] object from the current level number.
/// Kept as a convenience; screens that push a specific level number generate
/// the level directly via [LevelGenerator.generateLevel].
final currentLevelProvider = Provider<Level>((ref) {
  return LevelGenerator.generateLevel(ref.watch(currentLevelNumberProvider));
});

// ── Game state ────────────────────────────────────────────────────────────────

enum GameStatus { playing, won, lost }

class GameState {
  final List<Position> playerPath;
  final int lives;
  final GameStatus status;
  final bool showHint;
  final Position? hintCell;
  final Set<Position> wrongCells;

  const GameState({
    this.playerPath = const [],
    this.lives = 3,
    this.status = GameStatus.playing,
    this.showHint = false,
    this.hintCell,
    this.wrongCells = const {},
  });

  GameState copyWith({
    List<Position>? playerPath,
    int? lives,
    GameStatus? status,
    bool? showHint,
    Position? hintCell,
    bool clearHintCell = false,
    Set<Position>? wrongCells,
  }) {
    return GameState(
      playerPath: playerPath ?? this.playerPath,
      lives: lives ?? this.lives,
      status: status ?? this.status,
      showHint: showHint ?? this.showHint,
      hintCell: clearHintCell ? null : (hintCell ?? this.hintCell),
      wrongCells: wrongCells ?? this.wrongCells,
    );
  }
}

// ── Game notifier ─────────────────────────────────────────────────────────────

class GameNotifier extends StateNotifier<GameState> {
  final Level level;

  GameNotifier(this.level) : super(const GameState());

  /// Called when the player first touches the grid.
  /// Only starts a path if the touch is on the start cell.
  void startPath(Position pos) {
    if (state.status != GameStatus.playing) return;
    if (pos == level.start) {
      state = state.copyWith(
        playerPath: [pos],
        wrongCells: {},
        showHint: false,
        clearHintCell: true,
      );
    }
  }

  /// Called on each drag update.  Adds [pos] to the path if the move is valid.
  void extendPath(Position pos) {
    if (state.status != GameStatus.playing) return;
    final path = state.playerPath;
    if (path.isEmpty) return;
    if (path.contains(pos)) return; // no revisiting

    final last = path.last;
    // Must be orthogonally adjacent.
    final dr = (pos.row - last.row).abs();
    final dc = (pos.col - last.col).abs();
    if (dr + dc != 1) return;

    // The arrow at the last cell determines the only valid next step.
    final arrow = level.grid[last.row][last.col];
    if (arrow == ArrowDirection.none) return;

    if (last.move(arrow) != pos) {
      // Wrong direction — lose a life and mark the bad cell.
      final newLives = state.lives - 1;
      final wrong = {...state.wrongCells, pos};
      state = state.copyWith(
        lives: newLives,
        wrongCells: wrong,
        status: newLives <= 0 ? GameStatus.lost : GameStatus.playing,
      );
      return;
    }

    final newPath = [...path, pos];
    if (pos == level.exit) {
      state = state.copyWith(
        playerPath: newPath,
        status: GameStatus.won,
        wrongCells: {},
        showHint: false,
        clearHintCell: true,
      );
    } else {
      state = state.copyWith(
        playerPath: newPath,
        wrongCells: {},
        showHint: false,
        clearHintCell: true,
      );
    }
  }

  /// Reveals the next correct cell and costs one life.
  void useHint() {
    if (state.status != GameStatus.playing) return;
    if (state.lives <= 1) return;

    final searchFrom = state.playerPath.isEmpty ? level.start : state.playerPath.last;
    final idx = level.solutionPath.indexOf(searchFrom);
    if (idx < 0 || idx >= level.solutionPath.length - 1) return;

    final nextHint = level.solutionPath[idx + 1];
    final newLives = state.lives - 1;
    state = state.copyWith(
      lives: newLives,
      showHint: true,
      hintCell: nextHint,
      status: newLives <= 0 ? GameStatus.lost : GameStatus.playing,
    );
  }

  /// Resets the level to its initial state.
  void resetLevel() => state = const GameState();
}

final gameProvider =
    StateNotifierProvider.family<GameNotifier, GameState, Level>(
  (ref, level) => GameNotifier(level),
);

// ── Progress persistence ──────────────────────────────────────────────────────

class ProgressNotifier extends StateNotifier<Map<String, dynamic>> {
  ProgressNotifier() : super({'highestLevel': 1, 'stars': <int, int>{}}) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final highest = prefs.getInt('highestLevel') ?? 1;
    final rawList = prefs.getStringList('stars') ?? [];
    final stars = <int, int>{};
    for (final entry in rawList) {
      final parts = entry.split(':');
      if (parts.length == 2) {
        try {
          stars[int.parse(parts[0])] = int.parse(parts[1]);
        } on FormatException catch (e) {
          // Skip corrupted entries; they'll be overwritten on next save.
          debugPrint('ProgressNotifier: skipping bad entry "$entry": $e');
        }
      }
    }
    state = {'highestLevel': highest, 'stars': stars};
  }

  Future<void> completeLevel(int levelNumber, int livesLeft) async {
    final newStars = livesLeft == 3
        ? 3
        : livesLeft == 2
            ? 2
            : 1;
    final existing = state['stars'] as Map<int, int>;
    final updated = Map<int, int>.from(existing);
    if (newStars > (updated[levelNumber] ?? 0)) {
      updated[levelNumber] = newStars;
    }

    final newHighest = max(state['highestLevel'] as int, levelNumber + 1);
    state = {'highestLevel': newHighest, 'stars': updated};

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('highestLevel', newHighest);
    await prefs.setStringList(
      'stars',
      updated.entries.map((e) => '${e.key}:${e.value}').toList(),
    );
  }

  int getStars(int levelNumber) =>
      (state['stars'] as Map<int, int>)[levelNumber] ?? 0;

  int get highestLevel => state['highestLevel'] as int;
}

final progressProvider =
    StateNotifierProvider<ProgressNotifier, Map<String, dynamic>>(
  (ref) => ProgressNotifier(),
);
