import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/game_provider.dart';
import 'game_screen.dart';

/// Paginated level-selection grid.
///
/// Shows levels in a 5-column grid.  Locked levels are greyed out.
/// Completed levels show 1–3 gold stars.  Scrolling near the bottom
/// automatically reveals the next batch of 100 levels (up to 10 000+).
class LevelSelectScreen extends ConsumerStatefulWidget {
  const LevelSelectScreen({super.key});

  @override
  ConsumerState<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends ConsumerState<LevelSelectScreen> {
  static const int _pageSize = 100;
  static const double _scrollThreshold = 200;

  int _visibleCount = _pageSize;
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >=
        _scroll.position.maxScrollExtent - _scrollThreshold) {
      setState(() => _visibleCount += _pageSize);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(progressProvider);
    final highest = progress['highestLevel'] as int;
    final stars = progress['stars'] as Map<int, int>;

    return Scaffold(
      backgroundColor: const Color(0xFFF0E6D3),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF0E6D3),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Select Level',
          style: TextStyle(
            color: Color(0xFFA06020),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF8B6343)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFD4B896)),
        ),
      ),
      body: CustomScrollView(
        controller: _scroll,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(12),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final level = index + 1;
                  if (level > _visibleCount) return null;
                  final unlocked = level <= highest;
                  final levelStars = stars[level] ?? 0;
                  return _LevelTile(
                    levelNumber: level,
                    unlocked: unlocked,
                    stars: levelStars,
                  );
                },
                childCount: _visibleCount,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                childAspectRatio: 1.0,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
            ),
          ),
          // Footer "More" button
          SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: TextButton(
                  onPressed: () => setState(() => _visibleCount += _pageSize),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.expand_more, color: Color(0xFF8B6343)),
                      Text('More',
                          style: TextStyle(
                              color: Color(0xFF8B6343), fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Level tile ─────────────────────────────────────────────────────────────────

class _LevelTile extends StatelessWidget {
  final int levelNumber;
  final bool unlocked;
  final int stars;

  const _LevelTile({
    required this.levelNumber,
    required this.unlocked,
    required this.stars,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: unlocked
          ? () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GameScreen(levelNumber: levelNumber),
                ),
              )
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: unlocked
              ? const Color(0xFFA06020)
              : const Color(0xFFCDBFA8),
          borderRadius: BorderRadius.circular(10),
          boxShadow: unlocked
              ? [
                  BoxShadow(
                    color: Colors.brown.withOpacity(0.25),
                    blurRadius: 4,
                    offset: const Offset(2, 2),
                  )
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$levelNumber',
              style: TextStyle(
                color: unlocked ? Colors.white : Colors.white60,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            if (stars > 0)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  3,
                  (i) => Icon(
                    Icons.star_rounded,
                    size: 9,
                    color: i < stars ? Colors.amber : Colors.white24,
                  ),
                ),
              )
            else if (!unlocked)
              const Icon(Icons.lock_rounded,
                  color: Colors.white54, size: 13),
          ],
        ),
      ),
    );
  }
}

