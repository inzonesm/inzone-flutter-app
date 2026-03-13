import 'package:flutter/material.dart';
import '../../models/types.dart';
import 'game_card.dart';

class GameGrid extends StatefulWidget {
  final List<GameData> games;
  final int maxGamesToShow;
  final String charID;
  final String? menuId;
  final Function(String) onGameSelect;
  final MiniGameTheme? theme;

  const GameGrid({
    super.key,
    required this.games,
    required this.maxGamesToShow,
    required this.charID,
    this.menuId,
    required this.onGameSelect,
    this.theme,
  });

  @override
  State<GameGrid> createState() => _GameGridState();
}

class _GameGridState extends State<GameGrid> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void didUpdateWidget(covariant GameGrid oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If the underlying games list shrinks (e.g., due to search), the current
    // page index may become out-of-range. Clamp and jump to a valid page.
    if (oldWidget.games.length != widget.games.length ||
        oldWidget.maxGamesToShow != widget.maxGamesToShow) {
      final totalPages = _totalPages;
      final clampedPage = totalPages <= 0 ? 0 : _currentPage.clamp(0, totalPages - 1);
      if (clampedPage != _currentPage) {
        setState(() {
          _currentPage = clampedPage;
        });
        // Jump immediately to avoid calling _getGamesForPage with an invalid page.
        if (_pageController.hasClients) {
          _pageController.jumpToPage(_currentPage);
        }
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  int get _totalPages {
    return (widget.games.length / widget.maxGamesToShow).ceil();
  }

  List<GameData> _getGamesForPage(int page) {
    if (widget.games.isEmpty) return const [];

    final len = widget.games.length;
    final start = (page * widget.maxGamesToShow).clamp(0, len);
    if (start >= len) return const [];

    final end = (start + widget.maxGamesToShow).clamp(start, len);
    return widget.games.sublist(start, end);
  }

  void _handlePageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  void _handleDotTap(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  double _calculateGridHeight(BuildContext context, int itemCount) {
    // Calculate exact grid height based on actual number of items displayed
    // Account for padding (20px left + 20px right = 40px) and spacing (12px between items)
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth - 40; // Subtract left/right padding from parent
    final cardWidth = (availableWidth - 24) / 3; // 24 = 2 * 12px spacing between 3 items
    final cardHeight = cardWidth / 0.75; // childAspectRatio
    final rowCount = (itemCount / 3).ceil(); // Calculate rows based on actual item count
    if (rowCount == 0) return 0;
    final gridHeight = (cardHeight * rowCount) + (12 * (rowCount - 1)); // card heights + spacing between rows
    return gridHeight;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.games.isEmpty) return const SizedBox.shrink();

    final showPagination = _totalPages > 1;
    
    // Calculate height based on current page games (to handle different page sizes)
    // This ensures if a page has only 3 games (1 row), it only takes up 1 row of height
    final totalPages = _totalPages;
    final safePage = totalPages <= 0 ? 0 : _currentPage.clamp(0, totalPages - 1);
    final currentPageGames = _getGamesForPage(safePage);
    final gridHeight = _calculateGridHeight(context, currentPageGames.length);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Game Grid with PageView for swiping
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          height: gridHeight,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (page) {
              _handlePageChanged(page);
              // Force rebuild to recalculate height for new page (which may have different number of games)
            },
            itemCount: _totalPages,
            itemBuilder: (context, pageIndex) {
              final pageGames = _getGamesForPage(pageIndex);
              return GridView.builder(
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(), // Disable GridView scrolling, PageView handles it
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.75, // Smaller ratio = taller cards
                ),
                itemCount: pageGames.length,
                itemBuilder: (context, index) {
                  return GameCard(
                    game: pageGames[index],
                    charID: widget.charID,
                    menuId: widget.menuId,
                    onGameSelect: widget.onGameSelect,
                    theme: widget.theme,
                  );
                },
              );
            },
          ),
        ),

        // Pagination dots - positioned right at bottom of grid with minimal spacing
        if (showPagination)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: SizedBox(
              height: 16, // Fixed height for pagination row
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_totalPages, (index) {
                  final isActive = index == _currentPage;
                  final accentColor = widget.theme?.accentColor ?? const Color(0xFF3B82F6);
                  return GestureDetector(
                    onTap: () => _handleDotTap(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: isActive
                            ? accentColor
                            : Colors.grey[300]!.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
      ],
    );
  }
}
