import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:colorful_safe_area/colorful_safe_area.dart';
import 'package:inzone/services/unity_bridge.dart';
import 'models/unity_game.dart';
import 'services/game_hub_service.dart';
import 'widgets/game_card.dart';
import 'widgets/game_detail_sheet.dart';

class GameHubScreen extends StatefulWidget {
  const GameHubScreen({super.key});

  @override
  State<GameHubScreen> createState() => _GameHubScreenState();
}

class _GameHubScreenState extends State<GameHubScreen> {
  final _service = GameHubService.instance;

  List<UnityGame> _games = [];
  List<String> _categories = [];
  String? _selectedCategory;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await _service.loadInstalledGames();

      final results = await Future.wait([
        _service.fetchGames(),
        _service.fetchCategories(),
      ]);

      if (!mounted) return;
      setState(() {
        _games = results[0] as List<UnityGame>;
        _categories = results[1] as List<String>;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[GameHub] Error loading games: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load games: $e')),
      );
    }
  }

  Future<void> _onCategorySelected(String? category) async {
    setState(() {
      _selectedCategory = category;
      _isLoading = true;
    });

    final games = category == null
        ? await _service.fetchGames()
        : await _service.fetchGamesByCategory(category);

    if (!mounted) return;
    setState(() {
      _games = games;
      _isLoading = false;
    });
  }

  void _openDetail(UnityGame game) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GameDetailSheet(
        game: game,
        onPlay: () {
          Navigator.of(context).pop();
          _launchGame(game);
        },
      ),
    );
  }

  Future<void> _launchGame(UnityGame game) async {
    try {
      // Send the scene name to Unity so it loads the right content
      await UnityBridge.instance.open(projectId: game.id, sceneName: game.sceneName);
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to launch ${game.title}: ${e.message}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ColorfulSafeArea(
      topColor: theme.canvasColor,
      bottomColor: theme.canvasColor,
      child: Scaffold(
        backgroundColor: theme.canvasColor,
        appBar: AppBar(
          title: const Text(
            'Game Hub',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: false,
          backgroundColor: theme.canvasColor,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadData,
                child: CustomScrollView(
                  slivers: [
                    // Category filter chips
                    if (_categories.isNotEmpty)
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: 44,
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            scrollDirection: Axis.horizontal,
                            itemCount: _categories.length + 1,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                return _filterChip('All', null, theme);
                              }
                              final cat = _categories[index - 1];
                              return _filterChip(cat, cat, theme);
                            },
                          ),
                        ),
                      ),

                    const SliverToBoxAdapter(child: SizedBox(height: 16)),

                    // Game grid
                    _games.isEmpty
                        ? SliverFillRemaining(
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.videogame_asset_off,
                                      size: 64, color: theme.disabledColor),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No games available yet',
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      color: theme.disabledColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            sliver: SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 14,
                                crossAxisSpacing: 14,
                                childAspectRatio: 0.78,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => GameCard(
                                  game: _games[index],
                                  onTap: () => _openDetail(_games[index]),
                                ),
                                childCount: _games.length,
                              ),
                            ),
                          ),

                    // Bottom padding
                    const SliverToBoxAdapter(child: SizedBox(height: 32)),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _filterChip(String label, String? category, ThemeData theme) {
    final isSelected = _selectedCategory == category;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => _onCategorySelected(category),
      selectedColor: theme.colorScheme.primary.withValues(alpha: 0.2),
      checkmarkColor: theme.colorScheme.primary,
      labelStyle: TextStyle(
        color: isSelected ? theme.colorScheme.primary : null,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}
