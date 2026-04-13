import 'package:flutter/material.dart';
import 'level_select_screen.dart';

/// Splash / home screen shown on app launch.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0E6D3),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),

            // ── Decorative arrows ───────────────────────────────────────
            const _DecorativeArrows(),

            const SizedBox(height: 40),

            // ── Title ──────────────────────────────────────────────────
            const Text(
              'Arrow Maze',
              style: TextStyle(
                color: Color(0xFFA06020),
                fontSize: 42,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Follow the arrows to escape!',
              style: TextStyle(
                color: Color(0xFF8B6343),
                fontSize: 16,
              ),
            ),

            const Spacer(flex: 2),

            // ── Play button ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const LevelSelectScreen(),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFA06020),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                  ),
                  child: const Text(
                    'PLAY',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3,
                    ),
                  ),
                ),
              ),
            ),

            const Spacer(flex: 3),
          ],
        ),
      ),
    );
  }
}

/// A grid of decorative Unicode arrows to give the home screen personality.
class _DecorativeArrows extends StatelessWidget {
  const _DecorativeArrows();

  static const _symbols = ['→', '↑', '←', '↓', '→', '↑', '←', '↓', '→', '↑', '←', '↓'];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 14,
      runSpacing: 6,
      children: _symbols
          .map(
            (s) => Text(
              s,
              style: TextStyle(
                color: const Color(0xFF8B6343).withOpacity(0.35),
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          )
          .toList(),
    );
  }
}
