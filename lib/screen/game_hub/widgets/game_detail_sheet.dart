import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/unity_game.dart';
import '../services/game_hub_service.dart';

/// Bottom sheet showing game details with download / play controls.
class GameDetailSheet extends StatefulWidget {
  final UnityGame game;
  final VoidCallback onPlay;

  const GameDetailSheet({
    super.key,
    required this.game,
    required this.onPlay,
  });

  @override
  State<GameDetailSheet> createState() => _GameDetailSheetState();
}

class _GameDetailSheetState extends State<GameDetailSheet> {
  final _service = GameHubService.instance;
  double _downloadProgress = 0;
  late GameDownloadState _state;

  @override
  void initState() {
    super.initState();
    _state = _service.getDownloadState(widget.game);
  }

  Future<void> _download() async {
    setState(() {
      _state = GameDownloadState.downloading;
      _downloadProgress = 0;
    });
    try {
      await _service.downloadGame(
        widget.game,
        onProgress: (p) {
          if (mounted) setState(() => _downloadProgress = p);
        },
      );
      if (mounted) setState(() => _state = GameDownloadState.downloaded);
    } catch (e) {
      if (mounted) {
        setState(() => _state = GameDownloadState.notDownloaded);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasUpdate = _service.hasUpdate(widget.game);

    return Container(
      decoration: BoxDecoration(
        color: theme.canvasColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Banner image
          if (widget.game.bannerUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: widget.game.bannerUrl,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    height: 180,
                    color: isDark ? Colors.grey[800] : Colors.grey[200],
                  ),
                  errorWidget: (_, __, ___) => Container(
                    height: 180,
                    color: isDark ? Colors.grey[800] : Colors.grey[200],
                    child: const Icon(Icons.broken_image, size: 48),
                  ),
                ),
              ),
            ),

          // Title + meta
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.game.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _chip(widget.game.category, theme),
                    const SizedBox(width: 8),
                    _chip('${widget.game.sizeMb} MB', theme),
                    const SizedBox(width: 8),
                    _chip('v${widget.game.version}', theme),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  widget.game.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ),

          // Action button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: _buildActionButton(theme, hasUpdate),
            ),
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildActionButton(ThemeData theme, bool hasUpdate) {
    switch (_state) {
      case GameDownloadState.notDownloaded:
        return ElevatedButton.icon(
          onPressed: _download,
          icon: const Icon(Icons.download_rounded),
          label: const Text('Download'),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        );

      case GameDownloadState.downloading:
        return ElevatedButton(
          onPressed: null,
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _downloadProgress,
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('${(_downloadProgress * 100).toInt()}%'),
            ],
          ),
        );

      case GameDownloadState.downloaded:
        return ElevatedButton.icon(
          onPressed: widget.onPlay,
          icon: Icon(hasUpdate ? Icons.update_rounded : Icons.play_arrow_rounded),
          label: Text(hasUpdate ? 'Update & Play' : 'Play'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        );
    }
  }

  Widget _chip(String label, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall,
      ),
    );
  }
}
