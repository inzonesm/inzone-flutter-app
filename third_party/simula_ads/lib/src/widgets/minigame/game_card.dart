import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/types.dart';
import '../../widgets/simula_provider.dart';

class GameCard extends StatefulWidget {
  final GameData game;
  final String charID;
  final String? menuId;
  final Function(String) onGameSelect;
  final MiniGameTheme? theme;

  const GameCard({
    super.key,
    required this.game,
    required this.charID,
    this.menuId,
    required this.onGameSelect,
    this.theme,
  });

  @override
  State<GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<GameCard> {
  bool _imageError = false;
  bool _imageLoading = true;
  final List<String> _fallbackIcons = ['🎲', '🎮', '🎰', '🧩', '🎯'];
  late String _randomFallback;

  @override
  void initState() {
    super.initState();
    _randomFallback = _fallbackIcons[Random().nextInt(_fallbackIcons.length)];
  }

  void _handleClick() {
    // Track menu game click if menuId is available
    if (widget.menuId != null && widget.menuId!.isNotEmpty) {
      try {
        final notifier = Provider.of<SimulaNotifier>(context, listen: false);
        notifier.apiClient.trackMenuGameClick(
          menuId: widget.menuId!,
          gameName: widget.game.name,
        );
      } catch (e) {
        // Silently fail - tracking is best effort
      }
    }
    
    widget.onGameSelect(widget.game.id);
  }

  @override
  Widget build(BuildContext context) {
    final iconBorderRadius = widget.theme?.iconCornerRadius ?? 8.0;
    final backgroundColor = widget.theme?.backgroundColor ?? Colors.white;
    final borderColor = widget.theme?.borderColor ?? Colors.grey[300]!;
    final titleFontColor = widget.theme?.titleFontColor ?? Colors.black87;
    final titleFont = widget.theme?.titleFont;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _handleClick,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              // Game Icon
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(iconBorderRadius),
                    color: backgroundColor,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(iconBorderRadius),
                    child: _imageError
                        ? Center(
                            child: Text(
                              widget.game.iconFallback ?? _randomFallback,
                              style: const TextStyle(
                                fontSize: 40,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          )
                        : Stack(
                            children: [
                              if (_imageLoading)
                                Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: titleFontColor,
                                    ),
                                  ),
                                ),
                              Positioned.fill(
                                child: Image.network(
                                  widget.game.iconUrl,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) {
                                      if (mounted) {
                                        WidgetsBinding.instance.addPostFrameCallback((_) {
                                          if (mounted) {
                                            setState(() {
                                              _imageLoading = false;
                                            });
                                          }
                                        });
                                      }
                                      return child;
                                    }
                                    return Center(
                                      child: SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: titleFontColor,
                                        ),
                                      ),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    if (mounted) {
                                      WidgetsBinding.instance.addPostFrameCallback((_) {
                                        if (mounted) {
                                          setState(() {
                                            _imageError = true;
                                            _imageLoading = false;
                                          });
                                        }
                                      });
                                    }
                                    return Center(
                                      child: Text(
                                        widget.game.iconFallback ?? _randomFallback,
                                        style: const TextStyle(
                                          fontSize: 40,
                                          decoration: TextDecoration.none,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            // Game Name - fixed height container to prevent image shrinking
            SizedBox(
              height: 40, // Fixed height for 2 lines of text
              child: Center(
                child: Text(
                  widget.game.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: titleFontColor,
                    fontFamily: titleFont,
                    decoration: TextDecoration.none,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }
}
