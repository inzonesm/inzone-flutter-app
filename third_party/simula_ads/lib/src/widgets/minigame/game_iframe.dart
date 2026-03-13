import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/types.dart';
import '../../widgets/simula_provider.dart';
import '../../utils/webview_security.dart';

/// Default Instagram comments dark gray color
const Color _defaultPlayableBorderColor = Color(0xFF262626);
const int _minPlayableHeight = 500;

class GameIframe extends StatefulWidget {
  final String gameId;
  final VoidCallback? onCharacterTap;
  final String charID;
  final String charName;
  final String? charImage;
  final List<Message> messages;
  final bool delegateChar;
  final String? charDesc;
  final Function(double?)? onClose; // Callback with optional resized height
  final Function(String)? onAdIdReceived;
  final String? menuId;

  /// Controls the height of the Mini Game iframe.
  /// - double < 1.0: percentage of screen height (e.g., 0.8 = 80%)
  /// - double >= 1.0: pixel value (e.g., 600.0 = 600px)
  /// - null: full screen (default behavior)
  /// Minimum height is 500px.
  final dynamic playableHeight; // double | null
  /// Controls the background color of the curved border area above the playable
  /// when playableHeight is not null (bottom sheet mode).
  /// Default: '#262626' (Instagram comments dark gray)
  final Color? playableBorderColor;

  const GameIframe({
    super.key,
    required this.gameId,
    this.onCharacterTap,
    required this.charID,
    required this.charName,
    this.charImage,
    this.messages = const [],
    this.delegateChar = true,
    this.charDesc,
    required this.onClose,
    this.onAdIdReceived,
    this.menuId,
    this.playableHeight,
    this.playableBorderColor,
  });

  @override
  State<GameIframe> createState() => _GameIframeState();
}

class _GameIframeState extends State<GameIframe> {
  String? _iframeUrl;
  bool _loading = true;
  String? _error;
  WebViewController? _webViewController;
  bool _hasLoaded = false;
  OverlayEntry? _overlayEntry;
  double? _currentHeight; // Track current height for draggable bottom sheet
  bool _isDragging = false;
  bool?
      _lastBottomSheetState; // Track last bottom sheet state to avoid redundant SystemChrome calls

  String _getInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return '?';
    }

    final parts = trimmed.split(RegExp(r'\s+'));
    final initials = parts
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0])
        .join()
        .toUpperCase();
    return initials.isEmpty ? trimmed[0].toUpperCase() : initials;
  }

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _initWebView();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasLoaded) {
      _hasLoaded = true;
      _loadGame();
      // Schedule overlay insertion after the current frame is built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _insertOverlay();
        }
      });
    }
  }

  @override
  void didUpdateWidget(GameIframe oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset current height if playableHeight prop changed
    if (oldWidget.playableHeight != widget.playableHeight) {
      setState(() {
        _currentHeight = null;
        _lastBottomSheetState = null; // Force SystemUI update
      });
      _updateOverlay();
    }
  }

  @override
  void dispose() {
    _removeOverlay();
    // Restore system UI when disposing
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  void _insertOverlay() {
    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      maintainState: false,
      opaque: false, // Allow touches to pass through to WebView
      builder: (context) {
        // Calculate position based on playableHeight
        final screenSize = MediaQuery.of(context).size;
        final (initialHeight, isBottomSheet) = _calculateHeight(screenSize);
        final containerHeight = _currentHeight ?? initialHeight;

        // Calculate close button position
        // If bottom sheet, position at top of container (screenHeight - containerHeight + offset)
        // If full screen, position at top of screen
        final closeButtonTop =
            isBottomSheet ? screenSize.height - containerHeight + 60 : 60.0;
        final characterButtonTop = closeButtonTop;
        final touchBlockerTop =
            isBottomSheet ? screenSize.height - containerHeight + 8 : 8.0;

        return Stack(
          children: [
            // Touch blocker area - prevents WebView from capturing touches in close button area
            Positioned(
              top: touchBlockerTop,
              right: 8,
              child: GestureDetector(
                onTap:
                    () {}, // Absorb taps to prevent WebView from receiving them
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 80,
                  height: 80,
                  color: Colors.transparent,
                ),
              ),
            ),
            // Close button
            Positioned(
              top: closeButtonTop,
              right: 16,
              child: Material(
                elevation: 10000,
                color: Colors.transparent,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    widget.onClose?.call(_currentHeight);
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.black87,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),

            Positioned(
              top: characterButtonTop,
              left: 16,
              child: Material(
                elevation: 10000,
                color: Colors.transparent,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onCharacterTap,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF14CFEE),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: widget.charImage != null &&
                              widget.charImage!.trim().isNotEmpty
                          ? Image.network(
                              widget.charImage!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.white,
                                  alignment: Alignment.center,
                                  child: Text(
                                    _getInitials(widget.charName),
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                );
                              },
                            )
                          : Container(
                              color: Colors.white,
                              alignment: Alignment.center,
                              child: Text(
                                _getInitials(widget.charName),
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
    overlay.insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _updateOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.markNeedsBuild();
    }
  }

  void _initWebView() {
    if (kIsWeb) return;

    try {
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onNavigationRequest: (NavigationRequest request) {
              final url = request.url;

              // Allow initial load of iframe URL
              if (_iframeUrl != null && url == _iframeUrl) {
                return NavigationDecision.navigate;
              }

              // Allow special/internal URLs
              for (final scheme in allowedSpecialSchemes) {
                if (url.startsWith(scheme)) {
                  return NavigationDecision.navigate;
                }
              }

              // Block javascript: URLs
              if (url.startsWith('javascript:')) {
                return NavigationDecision.prevent;
              }

              // Check if origin is allowed - open externally for better UX
              if (isOriginAllowed(url)) {
                launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)
                    .catchError((_) => false);
                return NavigationDecision.prevent;
              }

              // For any other navigation, open externally
              if (url.isNotEmpty && url != _iframeUrl) {
                launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)
                    .catchError((_) => false);
                return NavigationDecision.prevent;
              }

              return NavigationDecision.navigate;
            },
          ),
        );
    } catch (e) {
      // Silently handle WebView initialization errors
    }
  }

  void _loadGame() async {
    final notifier = Provider.of<SimulaNotifier>(context, listen: false);
    if (notifier.sessionId == null) {
      setState(() {
        _error = 'Session not available';
        _loading = false;
      });
      return;
    }

    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final response = await notifier.apiClient.getMinigame(
        gameType: widget.gameId,
        sessionId: notifier.sessionId!,
        w: MediaQuery.of(context).size.width.toInt() + 5,
        h: MediaQuery.of(context).size.height.toInt() + 5,
        charId: widget.charID,
        charName: widget.charName,
        charImage: widget.charImage ?? '',
        charDesc: widget.charDesc,
        messages: widget.messages,
        delegateChar: widget.delegateChar,
        menuId: widget.menuId,
      );

      if (mounted) {
        setState(() {
          _iframeUrl = response.iframeUrl;
          _loading = false;
        });

        if (widget.onAdIdReceived != null && response.adId.isNotEmpty) {
          widget.onAdIdReceived!(response.adId);
        }

        if (_iframeUrl != null && _webViewController != null) {
          _webViewController!.loadRequest(Uri.parse(_iframeUrl!));
        }
      }
    } catch (err) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load game. Please try again.';
          _loading = false;
        });
      }
    }
  }

  /// Calculate container height based on playableHeight prop
  /// - double <= 1.0: percentage of screen height (e.g., 0.8 = 80%, 1.0 = 100%)
  /// - double > 1.0: pixel value (e.g., 600.0 = 600px)
  /// - null: full screen
  /// Minimum height is enforced at 500px - if calculated height is below 500, defaults to 500
  (double containerHeight, bool isBottomSheet) _calculateHeight(
      Size screenSize) {
    final playableHeight = widget.playableHeight;

    // If no playableHeight or null, use full screen
    if (playableHeight == null) {
      return (screenSize.height, false);
    }

    double calculatedHeight;

    if (playableHeight is double) {
      if (playableHeight <= 1.0) {
        // Percentage value (e.g., 0.8 = 80%, 1.0 = 100%)
        final percentageValue = playableHeight;

        // Treat >= 0.95 or == 1.0 as full screen (no bottom sheet UI)
        if (percentageValue >= 0.95 || percentageValue == 1.0) {
          return (screenSize.height, false);
        }

        // Calculate height from percentage, then enforce minimum of 500px
        calculatedHeight = screenSize.height * percentageValue;
        if (calculatedHeight < _minPlayableHeight) {
          calculatedHeight = _minPlayableHeight.toDouble();
        }
        // Ensure we don't exceed screen height
        calculatedHeight = calculatedHeight.clamp(
            _minPlayableHeight.toDouble(), screenSize.height);
      } else {
        // Pixel value (e.g., 600.0 = 600px) - must be > 1.0
        // If the pixel value is >= screen height, treat as full screen
        if (playableHeight >= screenSize.height) {
          return (screenSize.height, false);
        }

        // If below minimum, default to minimum height
        calculatedHeight = playableHeight < _minPlayableHeight
            ? _minPlayableHeight.toDouble()
            : playableHeight;
        // Ensure we don't exceed screen height
        calculatedHeight = calculatedHeight.clamp(
            _minPlayableHeight.toDouble(), screenSize.height);
      }
    } else {
      // Invalid value, use full screen
      return (screenSize.height, false);
    }

    return (calculatedHeight, true);
  }

  void _updateSystemUI(bool isBottomSheet) {
    // Only update if state changed
    if (_lastBottomSheetState == isBottomSheet) return;
    _lastBottomSheetState = isBottomSheet;

    if (!isBottomSheet) {
      // Hide status bar for full screen
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.immersiveSticky,
        overlays: [],
      );
    } else {
      // Show status bar for bottom sheet
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
        overlays: SystemUiOverlay.values,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final (initialHeight, isBottomSheet) = _calculateHeight(screenSize);

    // Use current height if dragging, otherwise use calculated height
    final containerHeight = _currentHeight ?? initialHeight;
    final playableBorderColor =
        widget.playableBorderColor ?? _defaultPlayableBorderColor;

    // Update SystemUI based on bottom sheet state
    _updateSystemUI(isBottomSheet);

    if (isBottomSheet) {
      const sheetRadius = 16.0;
      return Container(
        color: Colors.black.withValues(alpha: 0.5),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(sheetRadius),
            child: Container(
              height: containerHeight,
              width: double.infinity,
              decoration: BoxDecoration(
                color: playableBorderColor,
                borderRadius: BorderRadius.circular(sheetRadius),
              ),
              child: Column(
                children: [
                  // Draggable handle
                  GestureDetector(
                    onPanStart: (details) {
                      // Only start dragging if the gesture starts near the handle (within handle area)
                      setState(() {
                        _isDragging = true;
                      });
                    },
                    onPanUpdate: (details) {
                      // Only process vertical drags (ignore horizontal swipes)
                      if (details.delta.dy.abs() > details.delta.dx.abs()) {
                        // Calculate new height based on drag delta (dragging up = decrease height)
                        final newHeight =
                            (containerHeight - details.delta.dy).clamp(
                          _minPlayableHeight.toDouble(),
                          screenSize.height,
                        );
                        setState(() {
                          _currentHeight = newHeight;
                        });
                        _updateOverlay();
                      }
                    },
                    onPanEnd: (_) {
                      setState(() {
                        _isDragging = false;
                      });
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      color: Colors.transparent,
                      child: Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Content
                  Expanded(
                    child: Container(
                      color: Colors.white,
                      child: _buildContent(isBottomSheet: true),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      color: Colors.black.withValues(alpha: 0.8),
      child: _buildContent(isBottomSheet: false),
    );
  }

  Widget _buildContent({required bool isBottomSheet}) {
    final textColor = isBottomSheet ? Colors.black87 : Colors.white;

    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: textColor),
            const SizedBox(height: 12),
            Text(
              'Loading game...',
              style: TextStyle(
                color: textColor,
                fontSize: 18,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            _error!,
            style: TextStyle(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.none,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_iframeUrl == null || _webViewController == null) {
      return Center(
        child: Text(
          'Game URL not available',
          style: TextStyle(
            color: textColor,
            decoration: TextDecoration.none,
          ),
        ),
      );
    }

    return WebViewWidget(controller: _webViewController!);
  }
}
