import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

/// Full-page in-app browser for server companion pages: the BisectHosting
/// Starbase panel (games.bisecthosting.com — sends X-Frame-Options so it can
/// only be a top-level load, which this is) and BlueMap/Dynmap live maps.
class ServerWebScreen extends StatefulWidget {
  final String title;
  final String url;
  const ServerWebScreen({super.key, required this.title, required this.url});

  @override
  State<ServerWebScreen> createState() => _ServerWebScreenState();
}

class _ServerWebScreenState extends State<ServerWebScreen> {
  InAppWebViewController? _controller;
  bool _loading = true;
  String _loadError = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.canvasColor,
      appBar: AppBar(
        backgroundColor: theme.canvasColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          widget.title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller?.reload(),
          ),
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            tooltip: 'Open in browser',
            onPressed: () => launchUrl(
              Uri.parse(widget.url),
              mode: LaunchMode.externalApplication,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(widget.url)),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                domStorageEnabled: true,
                databaseEnabled: true,
                hardwareAcceleration: true,
                useWideViewPort: true,
                loadWithOverviewMode: true,
                allowsInlineMediaPlayback: true,
              ),
              onWebViewCreated: (controller) => _controller = controller,
              onLoadStart: (_, __) => setState(() {
                _loading = true;
                _loadError = '';
              }),
              onLoadStop: (_, __) => setState(() => _loading = false),
              onReceivedError: (controller, request, error) {
                // Sub-resource failures are common on heavy panels; only treat
                // main-frame errors as fatal.
                if (request.isForMainFrame ?? true) {
                  setState(() {
                    _loading = false;
                    _loadError = error.description;
                  });
                }
              },
            ),
            if (_loading)
              ColoredBox(
                color: theme.canvasColor,
                child: Center(
                  child: CircularProgressIndicator(
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
              ),
            if (_loadError.isNotEmpty && !_loading)
              ColoredBox(
                color: theme.canvasColor,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 40,
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          'Couldn\'t load this page.\n$_loadError',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: theme.textTheme.bodyMedium?.color,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _loadError = '';
                            _loading = true;
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
