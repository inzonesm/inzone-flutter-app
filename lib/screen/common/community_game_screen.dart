import 'package:colorful_safe_area/colorful_safe_area.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:go_router/go_router.dart';
import 'package:inzone/data/community_game.dart';

class CommunityGameScreen extends StatefulWidget {
  final CommunityGame game;

  const CommunityGameScreen({super.key, required this.game});

  @override
  State<CommunityGameScreen> createState() => _CommunityGameScreenState();
}

class _CommunityGameScreenState extends State<CommunityGameScreen> {
  InAppWebViewController? _controller;
  bool _isLoading = true;
  String _loadError = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColorfulSafeArea(
      color: theme.canvasColor,
      child: Scaffold(
        backgroundColor: theme.canvasColor,
        appBar: AppBar(
          backgroundColor: theme.canvasColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: () => context.pop(),
          ),
          title: Text(
            widget.game.name,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _controller?.reload(),
            ),
          ],
        ),
        body: Stack(
          children: [
            InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(widget.game.gameUrl)),
              initialSettings: InAppWebViewSettings(
                mediaPlaybackRequiresUserGesture: false,
                allowsInlineMediaPlayback: true,
                iframeAllow: 'camera; microphone; geolocation; encrypted-media',
                iframeAllowFullscreen: true,
                javaScriptEnabled: true,
                domStorageEnabled: true,
                databaseEnabled: true,
                hardwareAcceleration: true,
                supportZoom: true,
                builtInZoomControls: false,
                displayZoomControls: false,
                useWideViewPort: true,
                loadWithOverviewMode: true,
              ),
              onWebViewCreated: (controller) => _controller = controller,
              onLoadStart: (_, __) {
                if (!mounted) return;
                setState(() {
                  _isLoading = true;
                  _loadError = '';
                });
              },
              onLoadStop: (_, __) {
                if (!mounted) return;
                setState(() => _isLoading = false);
              },
              onReceivedError: (_, __, error) {
                if (!mounted) return;
                setState(() {
                  _isLoading = false;
                  _loadError = 'Failed to load game: ${error.description}';
                });
              },
            ),
            if (_isLoading)
              Container(
                color: theme.canvasColor,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: theme.primaryColor),
                      const SizedBox(height: 16),
                      Text('Loading ${widget.game.name}…',
                          style: theme.textTheme.titleMedium),
                    ],
                  ),
                ),
              ),
            if (_loadError.isNotEmpty && !_isLoading)
              Container(
                color: theme.canvasColor,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error Loading Game',
                          style: theme.textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          _loadError,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _loadError = '';
                            _isLoading = true;
                          });
                          _controller?.reload();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
