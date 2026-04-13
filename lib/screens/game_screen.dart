import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vibration/vibration.dart';
import '../models/level.dart';
import '../generators/level_generator.dart';
import '../painters/maze_painter.dart';
import '../providers/game_provider.dart';

/// Main game screen — visual style matches the reference screenshot:
///
///   ┌──────────────────────────────────┐
///   │  ←    Level N    🎨  ⚙          │  ← custom top bar (no AppBar)
///   ├──────────────────────────────────┤
///   │  💧💧💧              💡 AD       │  ← lives row
///   │                                  │
///   │          [ M A Z E ]             │  ← MazePainter
///   │                                  │
///   └──────────────────────────────────┘
class GameScreen extends ConsumerStatefulWidget {
  final int levelNumber;
  const GameScreen({super.key, required this.levelNumber});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  late ConfettiController _confetti;
  late Level _level;
  late Size _mazeCanvasSize;

  // ── palette dialog state ──────────────────────────────────────────────────
  // (reserved for a future palette picker; currently shows a snackbar)

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 3));
    _level = LevelGenerator.generateLevel(widget.levelNumber);
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  // ── hit-testing ───────────────────────────────────────────────────────────

  Position? _posFromOffset(Offset local) {
    final cell = _cellSize();
    final ox = (_mazeCanvasSize.width - cell * _level.cols) / 2;
    final oy = (_mazeCanvasSize.height - cell * _level.rows) / 2;
    final col = ((local.dx - ox) / cell).floor();
    final row = ((local.dy - oy) / cell).floor();
    if (row < 0 || row >= _level.rows || col < 0 || col >= _level.cols) {
      return null;
    }
    return Position(row, col);
  }

  double _cellSize() {
    final c = _mazeCanvasSize;
    return c.width / _level.cols < c.height / _level.rows
        ? c.width / _level.cols
        : c.height / _level.rows;
  }

  // ── layout ────────────────────────────────────────────────────────────────

  Size _computeMazeSize(BuildContext ctx) {
    final s = MediaQuery.of(ctx).size;
    // Leave room for the top bar, lives row, and bottom instruction label.
    return Size(s.width - 24, s.height * 0.64);
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    _mazeCanvasSize = _computeMazeSize(context);
    final gameState = ref.watch(gameProvider(_level));
    final notifier = ref.read(gameProvider(_level).notifier);

    // Side-effects on state changes.
    ref.listen<GameState>(gameProvider(_level), (prev, next) async {
      if (next.status == GameStatus.won && prev?.status != GameStatus.won) {
        _confetti.play();
        await ref
            .read(progressProvider.notifier)
            .completeLevel(widget.levelNumber, next.lives);
      }
      if (next.lives < (prev?.lives ?? 3)) {
        final has = await Vibration.hasVibrator() ?? false;
        if (has) Vibration.vibrate(duration: 180);
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF0E6D3),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── top bar ──────────────────────────────────────────────
                _TopBar(
                  levelNumber: widget.levelNumber,
                  onBack: () => Navigator.of(context).pop(),
                ),
                const Divider(height: 1, color: Color(0xFFD4B896)),

                // ── lives + hint row ─────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      // Blue water drop lives
                      ...List.generate(3, (i) => Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(
                              Icons.water_drop_rounded,
                              size: 34,
                              color: i < gameState.lives
                                  ? const Color(0xFF1E88E5)
                                  : Colors.grey.shade300,
                            ),
                          )),
                      const Spacer(),
                      // AD hint button
                      _HintButton(
                        enabled: gameState.lives > 1 &&
                            gameState.status == GameStatus.playing,
                        onTap: notifier.useHint,
                      ),
                    ],
                  ),
                ),

                // ── maze ─────────────────────────────────────────────────
                Center(
                  child: GestureDetector(
                    onPanStart: (d) {
                      final pos = _posFromOffset(d.localPosition);
                      if (pos != null) notifier.startPath(pos);
                    },
                    onPanUpdate: (d) {
                      final pos = _posFromOffset(d.localPosition);
                      if (pos != null) notifier.extendPath(pos);
                    },
                    child: SizedBox(
                      width: _mazeCanvasSize.width,
                      height: _mazeCanvasSize.height,
                      child: CustomPaint(
                        painter: MazePainter(
                          level: _level,
                          playerPath: gameState.playerPath,
                          wrongCells: gameState.wrongCells,
                          showHint: gameState.showHint,
                          hintCell: gameState.hintCell,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Follow the arrows from  🟢  to  🟠',
                    style: TextStyle(
                      color: Colors.brown.shade600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),

            // ── confetti ─────────────────────────────────────────────────
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confetti,
                blastDirectionality: BlastDirectionality.explosive,
                emissionFrequency: 0.06,
                numberOfParticles: 22,
                gravity: 0.25,
              ),
            ),

            // ── win overlay ───────────────────────────────────────────────
            if (gameState.status == GameStatus.won)
              _WinOverlay(
                levelNumber: widget.levelNumber,
                livesLeft: gameState.lives,
              ),

            // ── lose overlay ──────────────────────────────────────────────
            if (gameState.status == GameStatus.lost)
              _LoseOverlay(
                onRetry: notifier.resetLevel,
                onBack: () => Navigator.of(context).pop(),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Top bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final int levelNumber;
  final VoidCallback onBack;

  const _TopBar({required this.levelNumber, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          // Back arrow
          GestureDetector(
            onTap: onBack,
            child: const Icon(Icons.arrow_back,
                color: Color(0xFF8B6343), size: 26),
          ),

          // Centred level title
          Expanded(
            child: Text(
              'Level $levelNumber',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFA06020),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Palette icon
          GestureDetector(
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Theme customisation coming soon!'),
                duration: Duration(seconds: 2),
              ),
            ),
            child: const Icon(Icons.palette_outlined,
                color: Color(0xFF8B6343), size: 26),
          ),
          const SizedBox(width: 12),

          // Settings icon
          GestureDetector(
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Settings coming soon!'),
                duration: Duration(seconds: 2),
              ),
            ),
            child: const Icon(Icons.settings_outlined,
                color: Color(0xFF8B6343), size: 26),
          ),
        ],
      ),
    );
  }
}

// ── Hint button ───────────────────────────────────────────────────────────────

/// Lightbulb button with an "AD" badge — mirrors the reference screenshot.
class _HintButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _HintButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: enabled
                  ? const Color(0xFFE8D5B7)
                  : Colors.grey.shade200,
              shape: BoxShape.circle,
              border: Border.all(
                color: enabled
                    ? const Color(0xFF8B6343)
                    : Colors.grey.shade300,
                width: 1.5,
              ),
            ),
            child: Icon(
              Icons.lightbulb_outline_rounded,
              color: enabled
                  ? const Color(0xFF8B6343)
                  : Colors.grey.shade400,
              size: 24,
            ),
          ),
          // "AD" badge
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFF8B6343),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'AD',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Win overlay ───────────────────────────────────────────────────────────────

class _WinOverlay extends ConsumerWidget {
  final int levelNumber;
  final int livesLeft;

  const _WinOverlay({required this.levelNumber, required this.livesLeft});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stars = livesLeft >= 3
        ? 3
        : livesLeft == 2
            ? 2
            : 1;

    return Container(
      color: Colors.black54,
      child: Center(
        child: Card(
          margin: const EdgeInsets.all(32),
          color: const Color(0xFFFBF3E4),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '🎉 Level Complete!',
                  style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    3,
                    (i) => Icon(
                      i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 38,
                      color: i < stars ? Colors.amber : Colors.grey.shade300,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('Next Level'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFA06020),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) =>
                            GameScreen(levelNumber: levelNumber + 1),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Back to Levels',
                    style: TextStyle(color: Color(0xFF8B6343)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Lose overlay ──────────────────────────────────────────────────────────────

class _LoseOverlay extends StatelessWidget {
  final VoidCallback onRetry;
  final VoidCallback onBack;

  const _LoseOverlay({required this.onRetry, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Card(
          margin: const EdgeInsets.all(32),
          color: const Color(0xFFFBF3E4),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '💧 No Lives Left!',
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  "You can do it — try again!",
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E88E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: onRetry,
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: onBack,
                  child: const Text(
                    'Back to Levels',
                    style: TextStyle(color: Color(0xFF8B6343)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
