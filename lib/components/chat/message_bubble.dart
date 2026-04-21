import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:inzone/config/custom_icons.dart';
import 'package:inzone/theme/app_colors.dart';
import 'package:inzone/theme/light_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

class MessageBubble extends StatelessWidget {
  final String message;
  final bool isMe;
  final DateTime? timestamp;
  final String? timestampLabel;
  final bool showTimestamp;
  final String? statusLabel;
  final String? senderName;
  final Widget? senderAvatar;
  final VoidCallback? onShare;
  final VoidCallback? onSenderTap;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? imageUrl;
  final String? videoUrl;
  final String? videoThumbnailUrl;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.timestamp,
    this.timestampLabel,
    this.showTimestamp = false,
    this.statusLabel,
    this.senderName,
    this.senderAvatar,
    this.onShare,
    this.onSenderTap,
    this.onTap,
    this.onLongPress,
    this.imageUrl,
    this.videoUrl,
    this.videoThumbnailUrl,
  });

  bool get _hasImage => imageUrl != null && imageUrl!.trim().isNotEmpty;

  bool get _hasVideo => videoUrl != null && videoUrl!.trim().isNotEmpty;

  bool get _hasMedia => _hasImage || _hasVideo;

  bool get _hasText => message.trim().isNotEmpty;

  double _mediaWidth(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    return (screenWidth * 0.72).clamp(180.0, 300.0);
  }

  double _mediaMaxHeight(BuildContext context) {
    final orientation = MediaQuery.orientationOf(context);
    return orientation == Orientation.landscape ? 240.0 : 360.0;
  }

  String? _visibleTimestampText() {
    if (timestampLabel != null && timestampLabel!.trim().isNotEmpty) {
      return timestampLabel!.trim();
    }
    if (timestamp == null) return null;
    return DateFormat('h:mm a').format(timestamp!.toLocal());
  }

  void _openFullscreenMedia(BuildContext context) {
    final timestampText = _visibleTimestampText();

    if (_hasImage) {
      Navigator.of(context).push(
        PageRouteBuilder<void>(
          opaque: true,
          fullscreenDialog: true,
          pageBuilder: (routeContext, animation, secondaryAnimation) {
            return _FullscreenChatImageViewer(
              imageUrl: imageUrl!,
              timestampText: timestampText,
            );
          },
        ),
      );
      return;
    }

    if (_hasVideo) {
      Navigator.of(context).push(
        PageRouteBuilder<void>(
          opaque: true,
          fullscreenDialog: true,
          pageBuilder: (routeContext, animation, secondaryAnimation) {
            return _FullscreenChatVideoViewer(
              videoUrl: videoUrl!,
              timestampText: timestampText,
            );
          },
        ),
      );
    }
  }

  Widget _buildMedia(BuildContext context) {
    if (!_hasMedia) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(bottom: _hasText ? 8.0 : 0.0),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openFullscreenMedia(context),
        child: SizedBox(
          width: _mediaWidth(context),
          child: _hasVideo
              ? _ChatVideoPreview(
                  videoUrl: videoUrl!,
                  videoThumbnailUrl: videoThumbnailUrl,
                  maxWidth: _mediaWidth(context),
                  maxHeight: _mediaMaxHeight(context),
                )
              : _ChatImagePreview(
                  imageUrl: imageUrl!,
                  maxWidth: _mediaWidth(context),
                  maxHeight: _mediaMaxHeight(context),
                ),
        ),
      ),
    );
  }

  Widget _buildTextBubble(BuildContext context) {
    if (!_hasText) return const SizedBox.shrink();

    final shouldShowMeta = !_hasMedia &&
        ((showTimestamp && timestampLabel != null) || statusLabel != null);
    final metaParts = <String>[];
    if (shouldShowMeta &&
        timestampLabel != null &&
        timestampLabel!.trim().isNotEmpty) {
      metaParts.add(timestampLabel!.trim());
    }
    if (shouldShowMeta &&
        statusLabel != null &&
        statusLabel!.trim().isNotEmpty) {
      metaParts.add(statusLabel!.trim());
    }
    final metaText = metaParts.join('  •  ');

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _hasMedia ? null : onTap,
      onLongPress: _hasMedia ? null : onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        margin: EdgeInsets.only(right: isMe ? 10 : 50, left: isMe ? 50 : 10),
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 0.5,
              spreadRadius: 0.5,
              offset: const Offset(0.5, 0.5),
            ),
          ],
          color: isMe
              ? Theme.of(context).myChatBubbleColor
              : Theme.of(context).otherChatBubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(8),
            topRight: const Radius.circular(8),
            bottomRight:
                isMe ? const Radius.circular(0) : const Radius.circular(8),
            bottomLeft:
                isMe ? const Radius.circular(8) : const Radius.circular(0),
          ),
        ),
        child: IntrinsicWidth(
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                style: TextStyle(
                  color: isMe
                      ? Theme.of(context).myChatTextColor
                      : Theme.of(context).otherChatTextColor,
                ),
              ),
              if (shouldShowMeta && metaText.isNotEmpty)
                SizedBox(
                  height: 14,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      metaText,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 10,
                        color: isMe
                            ? Theme.of(context).myChatTextColor
                            : Theme.of(context).otherChatTextColor,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (!isMe && senderAvatar != null) ...[
            GestureDetector(
              onTap: onSenderTap,
              child: senderAvatar!,
            ),
            const SizedBox(width: 2),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isMe && senderName != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: GestureDetector(
                      onTap: onSenderTap,
                      child: Text(
                        senderName!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                    ),
                  ),
                _buildMedia(context),
                _buildTextBubble(context),
                const SizedBox(height: 5),
              ],
            ),
          ),
          if (!isMe && onShare != null)
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: GestureDetector(
                onTap: onShare,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 15.0, right: 5.0),
                  child: SizedBox(
                    height: 25,
                    width: 25,
                    child: SvgPicture.asset(CustomIcons.send),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChatImagePreview extends StatefulWidget {
  final String imageUrl;
  final double maxWidth;
  final double maxHeight;

  const _ChatImagePreview({
    required this.imageUrl,
    required this.maxWidth,
    required this.maxHeight,
  });

  @override
  State<_ChatImagePreview> createState() => _ChatImagePreviewState();
}

class _ChatImagePreviewState extends State<_ChatImagePreview> {
  double? _aspectRatio;

  @override
  void initState() {
    super.initState();
    _loadImageInfo();
  }

  @override
  void didUpdateWidget(covariant _ChatImagePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _aspectRatio = null;
      _loadImageInfo();
    }
  }

  Future<void> _loadImageInfo() async {
    try {
      final provider = CachedNetworkImageProvider(widget.imageUrl);
      final stream = provider.resolve(const ImageConfiguration());
      final completer = Completer<ImageInfo>();
      late final ImageStreamListener listener;

      listener = ImageStreamListener(
        (imageInfo, synchronousCall) {
          if (!completer.isCompleted) {
            completer.complete(imageInfo);
          }
          stream.removeListener(listener);
        },
        onError: (error, stackTrace) {
          if (!completer.isCompleted) {
            completer.completeError(error, stackTrace);
          }
          stream.removeListener(listener);
        },
      );

      stream.addListener(listener);
      final imageInfo = await completer.future;
      if (!mounted) return;
      setState(() {
        _aspectRatio = imageInfo.image.width / imageInfo.image.height;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _aspectRatio = 1.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final aspectRatio = (_aspectRatio ?? 1.0).clamp(0.6, 1.8);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: widget.maxWidth,
        maxHeight: widget.maxHeight,
      ),
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: CachedNetworkImage(
          imageUrl: widget.imageUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: Colors.grey.shade300,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            color: Colors.grey.shade300,
            child: const Icon(Icons.error),
          ),
        ),
      ),
    );
  }
}

class _ChatVideoPreview extends StatefulWidget {
  final String videoUrl;
  final String? videoThumbnailUrl;
  final double maxWidth;
  final double maxHeight;

  const _ChatVideoPreview({
    required this.videoUrl,
    this.videoThumbnailUrl,
    required this.maxWidth,
    required this.maxHeight,
  });

  @override
  State<_ChatVideoPreview> createState() => _ChatVideoPreviewState();
}

class _ChatVideoPreviewState extends State<_ChatVideoPreview> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {
          _isInitialized = true;
        });
      });
  }

  @override
  void didUpdateWidget(covariant _ChatVideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _controller?.dispose();
      _isInitialized = false;
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
        ..initialize().then((_) {
          if (!mounted) return;
          setState(() {
            _isInitialized = true;
          });
        });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final aspectRatio =
        _isInitialized && controller != null && controller.value.aspectRatio > 0
            ? controller.value.aspectRatio.clamp(0.6, 1.8)
            : 1.0;
    final hasThumbnail = widget.videoThumbnailUrl != null &&
        widget.videoThumbnailUrl!.trim().isNotEmpty;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: widget.maxWidth,
        maxHeight: widget.maxHeight,
      ),
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: [
            if (hasThumbnail)
              CachedNetworkImage(
                imageUrl: widget.videoThumbnailUrl!,
                fit: BoxFit.cover,
              )
            else if (_isInitialized && controller != null)
              VideoPlayer(controller)
            else
              Container(color: Colors.black),
            Container(color: Colors.black.withOpacity(0.12)),
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.45),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 32,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FullscreenChatImageViewer extends StatefulWidget {
  final String imageUrl;
  final String? timestampText;

  const _FullscreenChatImageViewer({
    required this.imageUrl,
    this.timestampText,
  });

  @override
  State<_FullscreenChatImageViewer> createState() =>
      _FullscreenChatImageViewerState();
}

class _FullscreenChatImageViewerState
    extends State<_FullscreenChatImageViewer> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Center(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: CachedNetworkImage(
                    imageUrl: widget.imageUrl,
                    fit: BoxFit.contain,
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                    errorWidget: (context, url, error) => const Icon(
                      Icons.broken_image,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
            if (!isLandscape &&
                widget.timestampText != null &&
                widget.timestampText!.trim().isNotEmpty)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Align(
                  alignment: Alignment.center,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      widget.timestampText!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FullscreenChatVideoViewer extends StatefulWidget {
  final String videoUrl;
  final String? timestampText;

  const _FullscreenChatVideoViewer({
    required this.videoUrl,
    this.timestampText,
  });

  @override
  State<_FullscreenChatVideoViewer> createState() =>
      _FullscreenChatVideoViewerState();
}

class _FullscreenChatVideoViewerState
    extends State<_FullscreenChatVideoViewer> {
  late final VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {
          _isInitialized = true;
        });
      });
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayback() {
    if (!_isInitialized) return;
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final aspectRatio = _isInitialized && _controller.value.aspectRatio > 0
        ? _controller.value.aspectRatio.clamp(9 / 16, 16 / 9)
        : 9 / 16;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _togglePlayback,
          child: Stack(
            children: [
              Positioned.fill(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: aspectRatio,
                    child: _isInitialized
                        ? VideoPlayer(_controller)
                        : const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
              if (!isLandscape &&
                  widget.timestampText != null &&
                  widget.timestampText!.trim().isNotEmpty)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Align(
                    alignment: Alignment.center,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        widget.timestampText!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              if (!_isInitialized || !_controller.value.isPlaying)
                const Center(
                  child: Icon(
                    Icons.play_circle_fill,
                    color: Colors.white,
                    size: 72,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
