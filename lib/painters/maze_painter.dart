import 'dart:math';
import 'package:flutter/material.dart';
import '../models/level.dart';

/// Renders the Arrow Maze grid using wall-based corridors.
///
/// Visual style (matches reference screenshot):
///   • Beige/cream background
///   • Brown corridor walls drawn only where a cell boundary is closed
///   • Small directional arrowheads inside open cells
///   • Player path highlighted in translucent blue
///   • Wrong-move cells flash translucent red
///   • Start cell marked with a green dot, exit with an orange dot
///   • Hint cell highlighted in yellow
class MazePainter extends CustomPainter {
  final Level level;
  final List<Position> playerPath;
  final Set<Position> wrongCells;
  final bool showHint;
  final Position? hintCell;

  static const Color _background = Color(0xFFF0E6D3);
  static const Color _wallColor = Color(0xFF5C3317);
  static const Color _arrowColor = Color(0xFF5C3317);
  static const Color _pathColor = Color(0xFF4FC3F7);
  static const Color _wrongColor = Color(0xFFEF5350);
  static const Color _startColor = Color(0xFF43A047);
  static const Color _exitColor = Color(0xFFFF7043);
  static const Color _hintColor = Color(0xFFFFF176);

  const MazePainter({
    required this.level,
    required this.playerPath,
    required this.wrongCells,
    this.showHint = false,
    this.hintCell,
  });

  // ── CustomPainter ─────────────────────────────────────────────────────────

  @override
  void paint(Canvas canvas, Size size) {
    final cell = _cellSize(size);
    final ox = (size.width - cell * level.cols) / 2;
    final oy = (size.height - cell * level.rows) / 2;

    _fillBackground(canvas, size);
    _paintCellHighlights(canvas, cell, ox, oy);
    _paintPlayerPath(canvas, cell, ox, oy);
    _paintWalls(canvas, cell, ox, oy);
    _paintArrows(canvas, cell, ox, oy);
    _paintStartExit(canvas, cell, ox, oy);
  }

  @override
  bool shouldRepaint(MazePainter old) =>
      old.playerPath != playerPath ||
      old.wrongCells != wrongCells ||
      old.showHint != showHint ||
      old.hintCell != hintCell;

  // ── drawing helpers ────────────────────────────────────────────────────────

  double _cellSize(Size size) =>
      min(size.width / level.cols, size.height / level.rows);

  void _fillBackground(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = _background,
    );
  }

  void _paintCellHighlights(Canvas canvas, double cell, double ox, double oy) {
    final pathSet = playerPath.toSet();
    for (int r = 0; r < level.rows; r++) {
      for (int c = 0; c < level.cols; c++) {
        final pos = Position(r, c);
        final rect = Rect.fromLTWH(ox + c * cell, oy + r * cell, cell, cell);
        Color? color;
        if (wrongCells.contains(pos)) {
          color = _wrongColor.withOpacity(0.35);
        } else if (pathSet.contains(pos)) {
          color = _pathColor.withOpacity(0.30);
        } else if (showHint && hintCell == pos) {
          color = _hintColor.withOpacity(0.60);
        }
        if (color != null) {
          canvas.drawRect(rect, Paint()..color = color);
        }
      }
    }
  }

  void _paintPlayerPath(Canvas canvas, double cell, double ox, double oy) {
    if (playerPath.length < 2) return;
    final paint = Paint()
      ..color = _pathColor.withOpacity(0.80)
      ..strokeWidth = cell * 0.20
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    for (int i = 0; i < playerPath.length; i++) {
      final p = playerPath[i];
      final cx = ox + p.col * cell + cell / 2;
      final cy = oy + p.row * cell + cell / 2;
      if (i == 0) {
        path.moveTo(cx, cy);
      } else {
        path.lineTo(cx, cy);
      }
    }
    canvas.drawPath(path, paint);
  }

  /// Draw wall segments.  Only the sides listed in [Level.walls] are drawn.
  /// Adjacent open cells share a wall and it is drawn only once (each cell
  /// draws its own N and W walls, avoiding double-drawing shared edges).
  void _paintWalls(Canvas canvas, double cell, double ox, double oy) {
    final thick = (cell * 0.10).clamp(1.5, 4.0);
    final paint = Paint()
      ..color = _wallColor
      ..strokeWidth = thick
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;

    for (int r = 0; r < level.rows; r++) {
      for (int c = 0; c < level.cols; c++) {
        final ws = level.walls[r][c];
        final l = ox + c * cell;
        final t = oy + r * cell;
        final r2 = l + cell;
        final b = t + cell;

        if (ws.contains(Wall.north)) {
          canvas.drawLine(Offset(l, t), Offset(r2, t), paint);
        }
        if (ws.contains(Wall.south)) {
          canvas.drawLine(Offset(l, b), Offset(r2, b), paint);
        }
        if (ws.contains(Wall.west)) {
          canvas.drawLine(Offset(l, t), Offset(l, b), paint);
        }
        if (ws.contains(Wall.east)) {
          canvas.drawLine(Offset(r2, t), Offset(r2, b), paint);
        }
      }
    }
  }

  void _paintArrows(Canvas canvas, double cell, double ox, double oy) {
    final arrowPaint = Paint()
      ..color = _arrowColor
      ..strokeWidth = (cell * 0.09).clamp(1.0, 3.5)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (int r = 0; r < level.rows; r++) {
      for (int c = 0; c < level.cols; c++) {
        final dir = level.grid[r][c];
        if (dir == ArrowDirection.none) continue;
        final cx = ox + c * cell + cell / 2;
        final cy = oy + r * cell + cell / 2;
        _drawArrow(canvas, arrowPaint, cx, cy, cell * 0.28, dir);
      }
    }
  }

  void _drawArrow(
    Canvas canvas,
    Paint paint,
    double cx,
    double cy,
    double size,
    ArrowDirection dir,
  ) {
    final Offset from;
    final Offset to;
    switch (dir) {
      case ArrowDirection.up:
        from = Offset(cx, cy + size);
        to = Offset(cx, cy - size);
        break;
      case ArrowDirection.down:
        from = Offset(cx, cy - size);
        to = Offset(cx, cy + size);
        break;
      case ArrowDirection.left:
        from = Offset(cx + size, cy);
        to = Offset(cx - size, cy);
        break;
      case ArrowDirection.right:
        from = Offset(cx - size, cy);
        to = Offset(cx + size, cy);
        break;
      case ArrowDirection.none:
        return;
    }

    canvas.drawLine(from, to, paint);

    // Arrowhead
    final angle = atan2(to.dy - from.dy, to.dx - from.dx);
    const headRatio = 0.42;
    const headAngle = 0.48; // radians ≈ 27°
    final head1 = Offset(
      to.dx - size * headRatio * cos(angle - headAngle),
      to.dy - size * headRatio * sin(angle - headAngle),
    );
    final head2 = Offset(
      to.dx - size * headRatio * cos(angle + headAngle),
      to.dy - size * headRatio * sin(angle + headAngle),
    );
    canvas.drawLine(to, head1, paint);
    canvas.drawLine(to, head2, paint);
  }

  void _paintStartExit(Canvas canvas, double cell, double ox, double oy) {
    final r = cell * 0.20;

    // Start — green filled circle
    canvas.drawCircle(
      Offset(ox + level.start.col * cell + cell / 2,
             oy + level.start.row * cell + cell / 2),
      r,
      Paint()..color = _startColor,
    );

    // Exit — orange filled circle
    canvas.drawCircle(
      Offset(ox + level.exit.col * cell + cell / 2,
             oy + level.exit.row * cell + cell / 2),
      r,
      Paint()..color = _exitColor,
    );
  }
}
