import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/mwb_tokens.dart';
import '../core/widgets/bottom_nav.dart';
import '../features/audio/presentation/mini_player.dart';

/// One icon family (Material Rounded, filled) for every destination, as in
/// the reference navigation: solid glyphs, equal optical weight.
const shellDestinations = [
  MwbNavItem(label: 'Home', icon: Icons.home_rounded, activeIcon: Icons.home_rounded),
  MwbNavItem(label: 'Bible', icon: Icons.menu_book_rounded, activeIcon: Icons.menu_book_rounded),
  MwbNavItem(label: 'Discover', icon: Icons.auto_awesome_rounded, activeIcon: Icons.auto_awesome_rounded),
  MwbNavItem(label: 'Library', icon: Icons.bookmarks_rounded, activeIcon: Icons.bookmarks_rounded),
  MwbNavItem(label: 'Profile', icon: Icons.person_rounded, activeIcon: Icons.person_rounded),
];

/// Hosts the five primary tabs. Each tab keeps its own navigator, so scroll
/// position and pushed screens survive switching tabs.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell, required this.children});

  final StatefulNavigationShell navigationShell;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _FadeIndexedStack(index: navigationShell.currentIndex, children: children),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayer(),
          MwbBottomNav(
            items: shellDestinations,
            currentIndex: navigationShell.currentIndex,
            onSelected: (i) => navigationShell.goBranch(i, initialLocation: i == navigationShell.currentIndex),
          ),
        ],
      ),
    );
  }
}

/// IndexedStack that fades the incoming tab in. Inactive tabs stay mounted
/// (state preserved) but are excluded from painting, semantics and tickers.
class _FadeIndexedStack extends StatefulWidget {
  const _FadeIndexedStack({required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  State<_FadeIndexedStack> createState() => _FadeIndexedStackState();
}

class _FadeIndexedStackState extends State<_FadeIndexedStack> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: MwbMotion.medium, value: 1);

  @override
  void didUpdateWidget(_FadeIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: _controller, curve: MwbMotion.curve),
      child: IndexedStack(
        index: widget.index,
        sizing: StackFit.expand,
        children: [
          for (var i = 0; i < widget.children.length; i++)
            TickerMode(enabled: i == widget.index, child: widget.children[i]),
        ],
      ),
    );
  }
}
