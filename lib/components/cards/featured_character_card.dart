import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:inzone/data/inzone_avatar.dart';

class FeaturedCharacterCard extends StatelessWidget {
  const FeaturedCharacterCard({
    super.key,
    required this.avatar,
    required this.onChat,
    required this.onPlay,
    this.padding = const EdgeInsets.symmetric(horizontal: 4),
  });

  final InZoneAvatar avatar;
  final VoidCallback onChat;
  final VoidCallback onPlay;
  final EdgeInsetsGeometry padding;

  static double estimateHeight(
    BuildContext context,
    InZoneAvatar avatar,
    double maxWidth, {
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 4),
  }) {
    final resolvedPadding = padding.resolve(Directionality.of(context));
    final cardWidth = maxWidth - resolvedPadding.horizontal;
    if (cardWidth <= 0) return 0;

    final layout = _FeaturedCharacterLayout.resolve(
      context,
      avatar,
      cardWidth,
    );
    return layout.totalHeight;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final layout = _FeaturedCharacterLayout.resolve(
            context,
            avatar,
            constraints.maxWidth,
          );

          return Container(
            decoration: BoxDecoration(
              color: layout.theme.cardColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: layout.theme.dividerColor.withValues(alpha: 0.08),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                height: layout.totalHeight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: layout.imageHeight,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (avatar.profilePicture.isNotEmpty)
                            Image(
                              image: CachedNetworkImageProvider(
                                avatar.profilePicture,
                              ),
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                            ),
                          Positioned(
                            top: 12,
                            left: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                'Featured',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: layout.contentPadding,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  layout.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.visible,
                                  style: layout.titleStyle,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  layout.snippet,
                                  style: layout.snippetStyle,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _FeaturedChatButton(
                                onPressed: onChat,
                                textColor:
                                    layout.theme.textTheme.bodyLarge?.color,
                              ),
                              const SizedBox(width: 6),
                              _FeaturedPlayButton(onPressed: onPlay),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FeaturedPlayButton extends StatelessWidget {
  const _FeaturedPlayButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _FeaturedCharacterLayout.buttonHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF14CFEE),
              Color(0xFF2196F3),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.play_arrow, size: 16, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    'Play',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeaturedChatButton extends StatelessWidget {
  const _FeaturedChatButton({
    required this.onPressed,
    required this.textColor,
  });

  final VoidCallback onPressed;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _FeaturedCharacterLayout.buttonHeight,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: textColor,
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          minimumSize: const Size(0, _FeaturedCharacterLayout.buttonHeight),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        child: const Text('Chat'),
      ),
    );
  }
}

class _FeaturedCharacterLayout {
  const _FeaturedCharacterLayout({
    required this.theme,
    required this.title,
    required this.snippet,
    required this.titleStyle,
    required this.snippetStyle,
    required this.contentPadding,
    required this.imageHeight,
    required this.totalHeight,
  });

  final ThemeData theme;
  final String title;
  final String snippet;
  final TextStyle titleStyle;
  final TextStyle snippetStyle;
  final EdgeInsets contentPadding;
  final double imageHeight;
  final double totalHeight;

  static const double buttonHeight = 40.0;

  static _FeaturedCharacterLayout resolve(
    BuildContext context,
    InZoneAvatar avatar,
    double cardWidth,
  ) {
    final theme = Theme.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final snippet = avatar.greeting?.isNotEmpty == true
        ? avatar.greeting!
        : (avatar.bio.isNotEmpty
            ? avatar.bio
            : 'Tap to chat with ${avatar.name}');

    final horizontalPadding =
        (cardWidth * 0.04).clamp(12.0, 18.0).toDouble();
    const verticalPaddingTop = 10.0;
    const verticalPaddingBottom = 8.0;
    final contentPadding = EdgeInsets.fromLTRB(
      horizontalPadding,
      verticalPaddingTop,
      horizontalPadding,
      verticalPaddingBottom,
    );

    final imageHeight =
        (cardWidth * 0.48).clamp(160.0, 190.0).toDouble();
    final buttonsReserve = min(152.0, cardWidth * 0.48);
    final availableTextWidth =
        max(60.0, cardWidth - contentPadding.horizontal - buttonsReserve);

    final title = 'Play with ${avatar.name}';
    final titleStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: theme.textTheme.bodyLarge?.color,
    );
    final snippetStyle = TextStyle(
      fontSize: 12,
      height: 1.25,
      color: theme.textTheme.bodySmall?.color,
    );

    final titlePainter = TextPainter(
      text: TextSpan(text: title, style: titleStyle),
      textDirection: TextDirection.ltr,
      maxLines: 2,
      textScaler: textScaler,
    )..layout(maxWidth: availableTextWidth);

    final snippetPainter = TextPainter(
      text: TextSpan(text: snippet, style: snippetStyle),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout(maxWidth: availableTextWidth);

    final contentHeight = titlePainter.height + 6.0 + snippetPainter.height;
    const buttonsArea = buttonHeight;
    final totalHeight =
        imageHeight + contentPadding.vertical + max(contentHeight, buttonsArea);

    return _FeaturedCharacterLayout(
      theme: theme,
      title: title,
      snippet: snippet,
      titleStyle: titleStyle,
      snippetStyle: snippetStyle,
      contentPadding: contentPadding,
      imageHeight: imageHeight,
      totalHeight: totalHeight,
    );
  }
}
