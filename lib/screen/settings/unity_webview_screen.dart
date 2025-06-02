import 'package:colorful_safe_area/colorful_safe_area.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:go_router/go_router.dart';

class UnityWebviewScreen extends StatefulWidget {
  const UnityWebviewScreen({super.key});

  @override
  State<UnityWebviewScreen> createState() => _UnityWebviewScreenState();
}

class _UnityWebviewScreenState extends State<UnityWebviewScreen> {
  InAppWebViewController? webViewController;
  bool isLoading = true;
  String loadError = '';

  final String unityGameUrl = 'https://play.unity.com/en/games/0f091f97-fe19-42d7-8979-89f83feebbb2/inzonetester';

  @override
  Widget build(BuildContext context) {
    return ColorfulSafeArea(
      color: Theme.of(context).canvasColor,
      child: Scaffold(
        backgroundColor: Theme.of(context).canvasColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).canvasColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: () => context.pop(),
          ),
          title: Text(
            'Unity Game Test',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                webViewController?.reload();
              },
            ),
          ],
        ),
        body: Stack(
          children: [
            InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(unityGameUrl)),
              initialSettings: InAppWebViewSettings(
                useShouldOverrideUrlLoading: false,
                mediaPlaybackRequiresUserGesture: false,
                allowsInlineMediaPlayback: true,
                iframeAllow: "camera; microphone; geolocation; encrypted-media",
                iframeAllowFullscreen: true,
                javaScriptEnabled: true,
                domStorageEnabled: true,
                databaseEnabled: true,
                clearCache: false,
                clearSessionCache: false,
                hardwareAcceleration: true,
                supportZoom: true,
                builtInZoomControls: false,
                displayZoomControls: false,
                useWideViewPort: true,
                loadWithOverviewMode: true,
                userAgent: "Mozilla/5.0 (Linux; Android 10; SM-G975F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36",
              ),
              onWebViewCreated: (InAppWebViewController controller) {
                webViewController = controller;
              },
              onLoadStart: (InAppWebViewController controller, WebUri? url) {
                setState(() {
                  isLoading = true;
                  loadError = '';
                });
              },
              onLoadStop: (InAppWebViewController controller, WebUri? url) async {
                setState(() {
                  isLoading = false;
                });

                // Inject custom CSS to hide unnecessary elements and optimize for gaming
                await controller.evaluateJavascript(source: '''
                  // Hide any navigation or header elements that might interfere
                  var style = document.createElement('style');
                  style.innerHTML = `
                    body { 
                      margin: 0 !important; 
                      padding: 0 !important; 
                      overflow: hidden !important;
                    }
                    #unity-container, #gameContainer, .webgl-content {
                      width: 100vw !important;
                      height: 100vh !important;
                      position: fixed !important;
                      top: 0 !important;
                      left: 0 !important;
                      z-index: 9999 !important;
                    }
                    canvas {
                      width: 100% !important;
                      height: 100% !important;
                    }
                  `;
                  document.head.appendChild(style);
                ''');
              },
              onReceivedError: (InAppWebViewController controller, WebResourceRequest request, WebResourceError error) {
                setState(() {
                  isLoading = false;
                  loadError = 'Failed to load game: ${error.description}';
                });
              },
              onProgressChanged: (InAppWebViewController controller, int progress) {
                // Optional: You can show a progress indicator here
              },
            ),
            
            // Loading indicator
            if (isLoading)
              Container(
                color: Theme.of(context).canvasColor,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Loading Unity Game...',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ),

            // Error display
            if (loadError.isNotEmpty && !isLoading)
              Container(
                color: Theme.of(context).canvasColor,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error Loading Game',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          loadError,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            loadError = '';
                            isLoading = true;
                          });
                          webViewController?.reload();
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