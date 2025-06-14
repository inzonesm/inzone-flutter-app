import 'package:colorful_safe_area/colorful_safe_area.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebViewPage extends StatefulWidget {
  const WebViewPage({super.key});

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  late final WebViewController controller;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            setState(() {
              _progress = progress / 100.0;
            });
          },
          onPageStarted: (String url) {
            setState(() {
              _progress = 0.0;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _progress = 1.0;
            });
          },
          onWebResourceError: (WebResourceError error) {},
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.startsWith('https://www.youtube.com/')) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse('http://localhost:5173/'));
  }

  @override
  Widget build(BuildContext context) {
    return ColorfulSafeArea(
      color: Colors.transparent,
      bottom: false,
      child: Scaffold(
        body: Stack(
          children: [
            WebViewWidget(controller: controller),
            if (_progress < 1.0)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).primaryColor),
                ),
              ),
            Positioned(
              top: 3,
              left: 14,
              child: Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: GestureDetector(
                  onTap: () {
                    context.pop();
                  },
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: Theme.of(context).cardColor,
                    foregroundColor: Theme.of(context).cardColor,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 5),
                      child: Center(
                        child: Icon(
                          Icons.arrow_back_ios,
                          size: 18,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
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
