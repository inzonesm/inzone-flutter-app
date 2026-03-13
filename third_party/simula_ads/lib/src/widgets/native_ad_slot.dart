import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/types.dart';
import '../api/api_client.dart';
import '../utils/webview_security.dart';
import '../widgets/simula_provider.dart';

/// NativeAdSlot widget - displays Pinterest-style native ads that adapt to Chai's design system
class NativeAdSlot extends StatefulWidget {
  final String slot; // Placement identifier (e.g., 'feed', 'explore')
  final int position; // Index position in feed
  final NativeContext context; // Contextual signals for ad relevance
  final dynamic width; // enforce minWidth?
  final Function(AdData)? onImpression; // Fires when ad is viewable
  final Function(Exception)? onError; // Fires on error or no-fill

  const NativeAdSlot({
    super.key,
    required this.slot,
    required this.position,
    required this.context,
    this.width,
    this.onImpression,
    this.onError,
  });

  @override
  State<NativeAdSlot> createState() => _NativeAdSlotState();
}

class _NativeAdSlotState extends State<NativeAdSlot> with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  AdData? _ad;
  String? _error;
  bool _impressionTracked = false;
  bool _isViewportVisible = false;
  bool _iframeLoaded = false; // Track when iframe has finished loading
  SimulaApiClient? _apiClient; // Store API client reference for use in dispose
  SimulaNotifier? _notifier; // Store notifier reference for use in dispose
  bool _isFetching = false; // Track if a fetch is in progress to prevent duplicate calls
  bool _sessionListenerAdded = false; // Track if session listener was added
  double? _preservedWidth; // Preserve width once calculated to prevent shrinking
  double? _measuredHeight; // Height received from postMessage
  WebViewController? _webViewController; // WebView controller for fixed-size container

  @override
  bool get wantKeepAlive => _ad != null; // Keep widget alive once ad is loaded to prevent reload on scroll

  @override
  void initState() {
    super.initState();
    // Listen to app lifecycle changes
    WidgetsBinding.instance.addObserver(this);
    
    // Fetch ad after the widget is built (can't access Provider in initState)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _fetchAd();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Track viewport exit when app goes to background or is paused
    if (state == AppLifecycleState.paused || 
        state == AppLifecycleState.inactive || 
        state == AppLifecycleState.hidden) {
      // Only track if ad was visible in viewport
      if (_isViewportVisible) {
        _trackViewportExit(wasVisible: true);
      }
    }
  }

  @override
  void didUpdateWidget(NativeAdSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only reset loaded state if the ad actually changed (different ad ID)
    if (_ad != null && (oldWidget.slot != widget.slot || oldWidget.position != widget.position)) {
      setState(() {
        _iframeLoaded = false;
        _preservedWidth = null; // Reset preserved width if slot/position changed
      });
    } else if (_ad == null && _error == null) {
      // Only fetch ad if ad is null AND there's no error
      // If there's an error, never retry
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _fetchAd();
      });
    }
  }

  /// Track impression when 50% of ad is visible and iframe has loaded
  void _checkAndTrackImpression() {
    // Check all conditions before tracking
    if (_impressionTracked) {
      return;
    }
    if (_ad == null) {
      return;
    }
    if (!_iframeLoaded) {
      return;
    }
    if (!_isViewportVisible) {
      return;
    }
    
    // All conditions met - track the impression
    _impressionTracked = true;
    
    final simula = useSimula(context);
    simula.apiClient.trackImpression(_ad!.id);
    
    // Call the onImpression callback
    widget.onImpression?.call(_ad!);
  }

  /// Convert width/height to pixels, handling percentages
  /// Matches React Native SDK implementation
  double? _calculateEffectiveDimension(dynamic dimension, double screenDimension, {bool isWidth = false}) {
    if (dimension == null) return null;
    
    if (dimension is double || dimension is int) {
      final pixelValue = dimension is int ? dimension.toDouble() : dimension;
      if (pixelValue == double.infinity || pixelValue.isNaN) return null;
      return pixelValue;
    }
    
    if (dimension is String && dimension.contains('%')) {
      final percentageStr = dimension.replaceAll('%', '').trim();
      final percentage = double.tryParse(percentageStr);
      if (percentage != null) {
        return screenDimension * percentage / 100;
      }
    }
    
    return null;
  }

  Future<void> _fetchAd() async {
    // Never retry if there's an error - once failed, stay failed
    if (_error != null) {
      return;
    }
    
    // If ad already exists, don't fetch again
    if (_ad != null) return;
    
    // Prevent duplicate concurrent fetches
    if (_isFetching) {
      return;
    }

    final notifier = Provider.of<SimulaNotifier>(context, listen: false);
    // Store references for use in dispose
    _notifier ??= notifier;
    _apiClient ??= notifier.apiClient;
    
    // Check if we know there's no fill for this slot/position
    if (notifier.hasNoFill(widget.slot, widget.position)) {
      setState(() {
        _error = 'No ad available';
      });
      if (widget.onError != null) {
        widget.onError!.call(Exception('No ad available'));
      }
      return;
    }
    
    if (notifier.sessionId == null) {
      // Wait for session to be created, then retry
      if (!_sessionListenerAdded) {
        notifier.addListener(_onSessionReady);
        _sessionListenerAdded = true;
      }
      return;
    }
    
    // Remove listener if session is ready (in case it was added)
    if (_sessionListenerAdded) {
      notifier.removeListener(_onSessionReady);
      _sessionListenerAdded = false;
    }
    
    _isFetching = true;

    setState(() {
      _error = null;
    });

    try {
      // Calculate effective width from percentages if needed
      final mediaQuery = MediaQuery.of(context);
      final screenWidth = mediaQuery.size.width;
      
      final calculatedWidth = _calculateEffectiveDimension(widget.width, screenWidth, isWidth: true);
      final effectiveWidth = calculatedWidth ?? screenWidth; // Use screen width as fallback if width is null (to fill container)
      
      // Use fetchAndCacheAd which checks cache first and reuses the same ad_id for viewport tracking
      final wasCached = notifier.getCachedAd(widget.slot, widget.position) != null;
      final cachedHeight = notifier.getCachedHeight(widget.slot, widget.position);
      final ad = await notifier.fetchAndCacheAd(
        slot: widget.slot,
        position: widget.position,
        sessionId: notifier.sessionId!,
        context: widget.context.filterForPrivacy(notifier.hasPrivacyConsent),
        width: effectiveWidth,
      );

      if (mounted) {
        if (ad != null) {
          setState(() {
            _ad = ad;
            _iframeLoaded = cachedHeight != null; // If height is cached, mark as loaded
            _measuredHeight = cachedHeight; // Use cached height if available
            _webViewController = null; // Reset controller to reinitialize
            // Only preserve width if this is a fresh fetch, not a cached one
            // For cached ads, we'll calculate width in build() with proper constraints
            if (!wasCached) {
              _preservedWidth = effectiveWidth;
            }
          });
          
          // WebView will receive height via postMessage and update _measuredHeight
        } else {
          // No ad available (no-fill)
          setState(() {
            _error = 'No ad available';
          });
          widget.onError?.call(Exception('No ad available'));
        }
      }
    } catch (e) {
      if (mounted) {
        final error = e is Exception ? e : Exception(e.toString());
        setState(() {
          _error = e.toString();
        });
        if (widget.onError != null) {
          widget.onError!.call(error);
        }
      }
    } finally {
      _isFetching = false;
    }
  }

  void _onSessionReady() {
    final notifier = Provider.of<SimulaNotifier>(context, listen: false);
    if (notifier.sessionId != null) {
      notifier.removeListener(_onSessionReady);
      _sessionListenerAdded = false;
      // Only fetch if not already fetching, no ad exists, and no error exists
      // Never retry if there's an error
      if (!_isFetching && _ad == null && _error == null) {
        _fetchAd();
      }
    }
  }

  void _trackViewportEntry() {
    // Track viewport entry when ad becomes visible
    if (_ad != null && _apiClient != null) {
      _apiClient!.trackViewportEntry(_ad!.id);
    }
  }

  void _trackViewportExit({bool wasVisible = true}) {
    // Track viewport exit if ad is loaded and was visible
    // wasVisible parameter allows tracking even after _isViewportVisible is set to false
    if (_ad != null && wasVisible && _apiClient != null) {
      _apiClient!.trackViewportExit(_ad!.id);
    }
  }

  @override
  void dispose() {
    // Remove app lifecycle observer
    WidgetsBinding.instance.removeObserver(this);
    
    // Track viewport exit on widget disposal if ad was visible
    _trackViewportExit(wasVisible: _isViewportVisible);
    // Use stored notifier reference instead of accessing context
    if (_sessionListenerAdded && _notifier != null) {
      _notifier!.removeListener(_onSessionReady);
      _sessionListenerAdded = false;
    }
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    // Calculate expected size for placeholder
    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaQuery = MediaQuery.of(context);
        final screenWidth = mediaQuery.size.width;
        
        // Use preserved width if available, otherwise calculate from constraints
        final calculatedWidth = _preservedWidth ?? _calculateEffectiveDimension(
          widget.width,
          screenWidth,
          isWidth: true,
        );
        
        final actualWidth = calculatedWidth ?? constraints.maxWidth;
        final calculatedHeight = actualWidth * 1.4;
        final defaultHeight = calculatedHeight > 700.0 ? 700.0 : calculatedHeight;
        
        // Check for error or empty ad
        if (_error != null) {
          return const SizedBox.shrink();
        }
        
        // Check if URL is available - if not, return empty widget
        if (_ad != null) {
          // Check if iframeUrl is null or empty
          if (_ad!.iframeUrl == null || _ad!.iframeUrl!.isEmpty) {
            return const SizedBox.shrink();
          }

          // Show ad content directly
          // Height will be determined by postMessage from HTML, or fallback to null (no constraint)
          return _buildAdContent(context, constraints, null);
        }

        // No ad yet - return empty
        return const SizedBox.shrink();
      },
    );
  }

  /// Initialize WebView controller with JavaScript channel to receive height
  void _initWebViewController() {
    if (_ad == null || _ad!.iframeUrl == null || _ad!.iframeUrl!.isEmpty) {
      return;
    }

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..addJavaScriptChannel(
        'SimulaAdChannel',
        onMessageReceived: (JavaScriptMessage message) {
          try {
            final data = jsonDecode(message.message) as Map<String, dynamic>;
            if (data['type'] == 'AD_HEIGHT' && data['height'] != null) {
              final height = (data['height'] as num).toDouble();
              // Add a small buffer (10px) to prevent cut-off due to rounding or rendering differences
              final heightWithBuffer = height + 10.0;

              // Cache the height in the notifier so other widget instances can use it
              if (_notifier != null) {
                _notifier!.cacheHeight(widget.slot, widget.position, heightWithBuffer);
              }

              if (mounted) {
                setState(() {
                  _measuredHeight = heightWithBuffer;
                  _iframeLoaded = true;
                });
                // Track impression if ad is already visible
                _checkAndTrackImpression();
              }
            }
          } catch (e) {
            // Silently ignore parsing errors
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url;

            // Allow initial load of the iframe URL
            if (_ad!.iframeUrl != null && url == _ad!.iframeUrl) {
              return NavigationDecision.navigate;
            }

            // Allow special/internal URLs (about:blank, about:srcdoc, data:, blob:)
            for (final scheme in allowedSpecialSchemes) {
              if (url.startsWith(scheme)) {
                return NavigationDecision.navigate;
              }
            }

            // Block javascript: URLs for security
            if (url.startsWith('javascript:')) {
              return NavigationDecision.prevent;
            }

            // For any other navigation, open externally in browser
            // This ensures tracking links and click-through URLs open in the system browser
            if (url.isNotEmpty) {
              launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)
                  .catchError((_) => false);
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
          onPageFinished: (String url) {
            // Inject script to listen for postMessage and forward to channel
            _webViewController?.runJavaScript('''
              (function() {
                // Listen for postMessage events and forward to Flutter channel
                window.addEventListener('message', function(event) {
                  if (event.data && event.data.type === 'AD_HEIGHT' && event.data.height) {
                    try {
                      SimulaAdChannel.postMessage(JSON.stringify(event.data));
                    } catch (e) {
                      // Silently ignore errors
                    }
                  }
                });

                // Also try to measure height directly after a delay to catch cases where postMessage hasn't fired
                setTimeout(function() {
                  const iframe = document.getElementById('ad-iframe');
                  if (iframe) {
                    try {
                      if (iframe.contentDocument && iframe.contentDocument.readyState === 'complete') {
                        const scrollHeight = iframe.contentDocument.documentElement.scrollHeight;
                        if (scrollHeight > 0) {
                          SimulaAdChannel.postMessage(JSON.stringify({ type: 'AD_HEIGHT', height: scrollHeight }));
                        }
                      }
                    } catch (e) {
                      // Cross-origin error, that's okay - postMessage from HTML will handle it
                    }
                  }
                }, 1000);
              })();
            ''');
          },
        ),
      )
      ..loadRequest(Uri.parse(_ad!.iframeUrl!));
  }

  /// Build fixed-size WebView that receives height via postMessage
  Widget _buildFixedSizeWebView() {
    if (_ad == null) {
      return const SizedBox.shrink();
    }

    // Check if we have a URL to load
    final hasUrl = _ad!.iframeUrl != null && _ad!.iframeUrl!.isNotEmpty;
    if (!hasUrl) {
      return const SizedBox.shrink();
    }

    // Initialize controller if not already done
    if (_webViewController == null) {
      _initWebViewController();
    }

    if (_webViewController == null) {
      return const SizedBox.shrink();
    }

    // Show loading indicator while waiting for height measurement - radial lines spinner
    if (_measuredHeight == null) {
      return const Center(
        child: _RadialLinesSpinner(),
      );
    }

    // Wrap WebView in a container that matches the measured height exactly
    return SizedBox(
      width: double.infinity,
      height: _measuredHeight!,
      child: WebViewWidget(controller: _webViewController!),
    );
  }

  /// Build the actual ad content (WebView)
  Widget _buildAdContent(BuildContext context, BoxConstraints constraints, double? height) {
    // Fill container completely with WebView and wrap with VisibilityDetector for viewport tracking
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    
    // Use preserved width if available, otherwise calculate from constraints
    final calculatedWidth = _preservedWidth ?? _calculateEffectiveDimension(
      widget.width,
      screenWidth,
      isWidth: true,
    );
    final actualWidth = calculatedWidth ?? constraints.maxWidth;
    
    return VisibilityDetector(
      key: Key('ad_viewport_${_ad!.id}'),
      onVisibilityChanged: (VisibilityInfo info) {
        final wasVisible = _isViewportVisible;
        final isNowVisible = info.visibleFraction >= 0.5;
        // Track entry when ad enters viewport (was not visible, now visible)
        if (!wasVisible && isNowVisible) {
          _trackViewportEntry();
          _checkAndTrackImpression();
        }
        // Track exit when ad leaves viewport (was visible, now not visible)
        if (wasVisible && !isNowVisible) {
          _trackViewportExit(wasVisible: wasVisible);
        }
        _isViewportVisible = isNowVisible;
      },
        child: ClipRRect(
        borderRadius: BorderRadius.circular(0),
        clipBehavior: Clip.none, // Don't clip - let content expand
        child: SizedBox(
          width: actualWidth,
          // Use measured height from postMessage, or fallback to provided height
          // While waiting for height, use a small placeholder height to show loading indicator
          height: _measuredHeight ?? height ?? 50.0, // Small placeholder while waiting
          child: _buildFixedSizeWebView(),
        ),
      ),
    );
  }
}

/// Radial lines spinner widget - creates a spinner with radial lines (spokes) that rotate
class _RadialLinesSpinner extends StatefulWidget {
  const _RadialLinesSpinner();

  @override
  State<_RadialLinesSpinner> createState() => _RadialLinesSpinnerState();
}

class _RadialLinesSpinnerState extends State<_RadialLinesSpinner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200), // Duration for one full cycle (all 12 lines)
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(16, 16),
          painter: _RadialLinesPainter(_controller.value),
        );
      },
    );
  }
}

class _RadialLinesPainter extends CustomPainter {
  final double progress;

  _RadialLinesPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const lineCount = 12;
    final lineLength = radius * 0.6;
    const lineWidth = 1.5;

    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = lineWidth
      ..strokeCap = StrokeCap.round;

    // Calculate which line should be highlighted (0 to lineCount-1)
    final currentLine = (progress * lineCount).floor() % lineCount;
    
    for (int i = 0; i < lineCount; i++) {
      final angle = i * 2 * 3.14159 / lineCount;
      
      // Calculate opacity: bright for current line, fading for previous lines
      double opacity = 0.35; // Base opacity for all lines (increased from 0.15)
      
      // Make the current line and a few previous lines brighter
      final distance = (i - currentLine + lineCount) % lineCount;
      if (distance == 0) {
        opacity = 1.0; // Current line is brightest
      } else if (distance == 1) {
        opacity = 0.75; // Previous line is dimmer
      } else if (distance == 2) {
        opacity = 0.5; // Two lines back is even dimmer
      } else if (distance == 3) {
        opacity = 0.4; // Three lines back
      }
      
      paint.color = Colors.white.withValues(alpha: opacity);
      
      final startX = center.dx + (radius - lineLength) * math.cos(angle);
      final startY = center.dy + (radius - lineLength) * math.sin(angle);
      final endX = center.dx + radius * math.cos(angle);
      final endY = center.dy + radius * math.sin(angle);
      
      canvas.drawLine(
        Offset(startX, startY),
        Offset(endX, endY),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RadialLinesPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
