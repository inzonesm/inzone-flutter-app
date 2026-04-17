import 'dart:convert';
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
  final ValueChanged<String>? onGameOverText;
  final String charID;
  final String charName;
  final String? charImage;
  final List<Message> messages;
  final bool delegateChar;
  final String? charDesc;
  final Function(double?, String?)? onClose; // Callback with optional resized height and final game-over text
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
    this.onGameOverText,
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
  bool?
      _lastBottomSheetState; // Track last bottom sheet state to avoid redundant SystemChrome calls
  String? _lastGameOverTextSnapshot;

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

    final characterContextChanged = oldWidget.charID != widget.charID ||
        oldWidget.charName != widget.charName ||
        oldWidget.charImage != widget.charImage ||
        oldWidget.charDesc != widget.charDesc ||
        oldWidget.delegateChar != widget.delegateChar ||
        oldWidget.messages.length != widget.messages.length;

    if (characterContextChanged && _iframeUrl != null) {
      _loadGame();
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
        final safeTop = MediaQuery.of(context).padding.top;
        final (initialHeight, isBottomSheet) = _calculateHeight(screenSize);
        final containerHeight = _currentHeight ?? initialHeight;

        // Calculate close button position
        // If bottom sheet, position at top of container (screenHeight - containerHeight + offset)
        // If full screen, position below the safe area (dynamic island)
        final fullScreenButtonTop = safeTop + 8.0;
        final closeButtonTop =
            isBottomSheet ? screenSize.height - containerHeight + 60 : fullScreenButtonTop;
        final touchBlockerTop =
            isBottomSheet ? screenSize.height - containerHeight + 8 : safeTop;

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
                  onTap: () async {
                    final closeText = await _flushGameOverTelemetryBeforeClose();
                    widget.onClose?.call(_currentHeight, closeText ?? _lastGameOverTextSnapshot);
                  },
                  child: Container(
                    width: 32,
                    height: 32,
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
                      size: 18,
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

  String _normalizeJsReturnValue(dynamic raw) {
    if (raw == null) return '';
    if (raw is String) {
      final text = raw.trim();
      if (text.isEmpty) return '';

      if ((text.startsWith('"') && text.endsWith('"')) ||
          (text.startsWith("'") && text.endsWith("'"))) {
        try {
          final decoded = jsonDecode(text);
          if (decoded is String) return decoded.trim();
        } catch (_) {}
      }

      return text;
    }
    return raw.toString().trim();
  }

  String _buildLabeledTelemetryText(Map<String, dynamic> payload) {
    final buffer = StringBuffer();

    void append(String key, String label) {
      final value = payload[key]?.toString().trim() ?? '';
      if (value.isEmpty || value.toLowerCase() == 'null') return;
      if (buffer.isNotEmpty) buffer.write(' | ');
      buffer.write('$label: $value');
    }

    final text = payload['text']?.toString().trim() ?? '';
    if (text.isNotEmpty) buffer.write(text);

    append('score', 'Score');
    append('level', 'Level');
    append('turns', 'Turns');
    append('coins', 'Coins');
    append('distance', 'Distance');
    append('action', 'Action');
    append('title', 'Title');

    return buffer.toString().trim();
  }

  Future<String?> _flushGameOverTelemetryBeforeClose() async {
    if (kIsWeb || _webViewController == null) return _lastGameOverTextSnapshot;

    try {
      final raw = await _webViewController!.runJavaScriptReturningResult(
        '''
(() => {
  try {
    const collectLivePayload = () => {
      const lines = [];

      const isVisible = (el) => {
        if (!el || !el.getBoundingClientRect) return false;
        const style = window.getComputedStyle ? window.getComputedStyle(el) : null;
        if (style && (style.display === 'none' || style.visibility === 'hidden' || style.opacity === '0')) {
          return false;
        }
        const rect = el.getBoundingClientRect();
        return rect.width > 0 && rect.height > 0;
      };

      const collectFromDocument = (doc) => {
        if (!doc || !doc.querySelectorAll) return;
        const nodes = doc.querySelectorAll('h1, h2, h3, h4, h5, h6, p, span, div, button, strong');
        for (let i = 0; i < nodes.length; i += 1) {
          const el = nodes[i];
          if (!isVisible(el)) continue;
          const text = (el.innerText || el.textContent || '').replace(/\s+/g, ' ').trim();
          if (!text) continue;
          lines.push(text);
          if (lines.length >= 40) return;
        }
      };

      collectFromDocument(document);

      if (lines.length < 40) {
        const iframes = document.querySelectorAll('iframe');
        for (let i = 0; i < iframes.length; i += 1) {
          const iframe = iframes[i];
          try {
            const subDoc = iframe.contentDocument || (iframe.contentWindow ? iframe.contentWindow.document : null);
            if (!subDoc) continue;
            collectFromDocument(subDoc);
            if (lines.length >= 40) break;
          } catch (_) {
            // Cross-origin iframe; cannot inspect.
          }
        }
      }

      const fullText = lines.join(' | ');
      const lower = fullText.toLowerCase();
      const extractNumber = (value) => {
        if (value === null || value === undefined) return null;
        const text = String(value).replace(/,/g, '').trim();
        if (!text) return null;
        const num = Number(text);
        if (!Number.isFinite(num)) return null;
        return String(Math.round(num));
      };

      const findStatsInObjectGraph = () => {
        const queue = [];
        const seen = new Set();
        let foundScore = null;
        let foundLevel = null;

        const pushCandidate = (obj) => {
          if (!obj || typeof obj !== 'object') return;
          if (seen.has(obj)) return;
          seen.add(obj);
          queue.push(obj);
        };

        pushCandidate(window);

        const hardLimit = 700;
        let inspected = 0;

        while (queue.length > 0 && inspected < hardLimit && (foundScore === null || foundLevel === null)) {
          const current = queue.shift();
          inspected += 1;

          let keys = [];
          try {
            keys = Object.keys(current);
          } catch (_) {
            continue;
          }

          for (let i = 0; i < keys.length; i += 1) {
            const key = keys[i];
            const lowerKey = key.toLowerCase();
            let value;
            try {
              value = current[key];
            } catch (_) {
              continue;
            }

            if (foundScore === null && (lowerKey.includes('score') || lowerKey.includes('point'))) {
              const parsed = extractNumber(value);
              if (parsed !== null && parsed !== '0') foundScore = parsed;
            }

            if (foundLevel === null && (lowerKey.includes('level') || lowerKey.includes('stage') || lowerKey === 'lvl')) {
              const parsed = extractNumber(value);
              if (parsed !== null && parsed !== '0') foundLevel = parsed;
            }

            if (value && typeof value === 'object') {
              pushCandidate(value);
            } else if (typeof value === 'string') {
              if (foundScore === null) {
                const scoreInText = value.match(/(?:score|points|best)\s*[:=-]?\s*(\d[\d,]*)/i) || value.match(/(\d[\d,]*)\s*(?:score|points|best)\b/i);
                if (scoreInText) foundScore = String(scoreInText[1]).replace(/,/g, '');
              }
              if (foundLevel === null) {
                const levelInText = value.match(/(?:level|stage)\s*[:=-]?\s*(\d+)/i) || value.match(/level\s*(\d+)\s*cleared/i);
                if (levelInText) foundLevel = String(levelInText[1]);
              }
            }
          }
        }

        return { score: foundScore, level: foundLevel };
      };

      const findStatsInStorage = () => {
        let storageScore = null;
        let storageLevel = null;

        const inspectStorage = (storage) => {
          if (!storage) return;
          for (let i = 0; i < storage.length; i += 1) {
            const k = storage.key(i);
            if (!k) continue;
            const lk = k.toLowerCase();
            const v = storage.getItem(k) || '';

            if (storageScore === null && (lk.includes('score') || v.toLowerCase().includes('score'))) {
              const match = v.match(/(?:score|points|best)\s*[:=-]?\s*(\d[\d,]*)/i) || v.match(/(\d[\d,]*)\s*(?:score|points|best)\b/i);
              if (match) storageScore = String(match[1]).replace(/,/g, '');
            }

            if (storageLevel === null && (lk.includes('level') || v.toLowerCase().includes('level'))) {
              const match = v.match(/(?:level|stage)\s*[:=-]?\s*(\d+)/i) || v.match(/level\s*(\d+)\s*cleared/i);
              if (match) storageLevel = String(match[1]);
            }
          }
        };

        try { inspectStorage(window.localStorage); } catch (_) {}
        try { inspectStorage(window.sessionStorage); } catch (_) {}

        return { score: storageScore, level: storageLevel };
      };

      const scoreMatch =
        lower.match(/(?:score|points|best)\s*[:=-]?\s*(\d[\d,]*)/i) ||
        lower.match(/(\d[\d,]*)\s*(?:score|points|best)\b/i);
      const levelMatch =
        lower.match(/(?:level|stage)\s*[:=-]?\s*(\d+)/i) ||
        lower.match(/level\s*(\d+)\s*cleared/i);
      const graphStats = findStatsInObjectGraph();
      const storageStats = findStatsInStorage();

      return {
        text: fullText.substring(0, 800),
        score:
          scoreMatch ? String(scoreMatch[1]).replace(/,/g, '') :
          (graphStats.score !== null ? graphStats.score : storageStats.score),
        level:
          levelMatch ? String(levelMatch[1]) :
          (graphStats.level !== null ? graphStats.level : storageStats.level),
      };
    };

    const cachedRaw = window.__inzoneLastInzoneGameOverPayload || '';
    let cached = null;
    if (cachedRaw && typeof cachedRaw === 'string') {
      try { cached = JSON.parse(cachedRaw); } catch (_) {}
    }

    const live = collectLivePayload();
    const merged = {
      text: (live.text && live.text.length > 0) ? live.text : (cached && cached.text ? cached.text : ''),
      score: (live.score != null && live.score !== '') ? live.score : (cached && cached.score ? String(cached.score) : null),
      level: (live.level != null && live.level !== '') ? live.level : (cached && cached.level ? String(cached.level) : null),
      turns: cached && cached.turns ? String(cached.turns) : null,
      coins: cached && cached.coins ? String(cached.coins) : null,
      distance: cached && cached.distance ? String(cached.distance) : null,
      action: cached && cached.action ? String(cached.action) : null,
      title: cached && cached.title ? String(cached.title) : null,
    };

    const normalized = JSON.stringify(merged);
    try { window.__inzoneLastInzoneGameOverPayload = normalized; } catch (_) {}
    return normalized;
  } catch (_) {
    try { return window.__inzoneLastInzoneGameOverPayload || ''; } catch (_) { return ''; }
  }
})();
''',
      );

      final normalized = _normalizeJsReturnValue(raw);
      if (normalized.isEmpty) return _lastGameOverTextSnapshot;

      String bestText = normalized;
      try {
        final decoded = jsonDecode(normalized);
        if (decoded is String) {
          bestText = decoded.trim();
        } else if (decoded is Map) {
          bestText =
              _buildLabeledTelemetryText(decoded.cast<String, dynamic>());
        }
      } catch (_) {}

      if (bestText.isNotEmpty && bestText != _lastGameOverTextSnapshot) {
        _lastGameOverTextSnapshot = bestText;
        widget.onGameOverText?.call(bestText);
      }
      return _lastGameOverTextSnapshot;
    } catch (_) {
      return _lastGameOverTextSnapshot;
    }
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
        ..addJavaScriptChannel(
          'InzoneCharacterTap',
          onMessageReceived: (_) {
            widget.onCharacterTap?.call();
          },
        )
        ..addJavaScriptChannel(
          'InzoneGameOverText',
          onMessageReceived: (message) {
            try {
              final dynamic decoded = jsonDecode(message.message);
              if (decoded is Map) {
                final buffer = StringBuffer();

                final text = (decoded['text'] ?? '').toString().trim();
                if (text.isNotEmpty) {
                  buffer.write(text);
                }

                void appendLabeled(String key, String label) {
                  final value = (decoded[key] ?? '').toString().trim();
                  if (value.isNotEmpty && value.toLowerCase() != 'null') {
                    if (buffer.isNotEmpty) buffer.write(' | ');
                    buffer.write('$label: $value');
                  }
                }

                appendLabeled('score', 'Score');
                appendLabeled('level', 'Level');
                appendLabeled('turns', 'Turns');
                appendLabeled('coins', 'Coins');
                appendLabeled('distance', 'Distance');
                appendLabeled('action', 'Action');
                appendLabeled('title', 'Title');

                final finalText = buffer.toString().trim();
                if (finalText.isNotEmpty) {
                  _lastGameOverTextSnapshot = finalText;
                  widget.onGameOverText?.call(finalText);
                }
              }
            } catch (_) {}
          },
        )
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
            onPageFinished: (url) {
              _injectCharacterTapBridgeScript();
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

      final List<Message> requestMessages = [
        ...widget.messages,
        Message(
          role: 'assistant',
          content:
              'Current game is ${widget.gameId}. Keep responses concise and useful for this specific game context.',
        ),
      ];

      final response = await notifier.apiClient.getMinigame(
        gameType: widget.gameId,
        sessionId: notifier.sessionId!,
        w: MediaQuery.of(context).size.width.toInt() + 5,
        h: MediaQuery.of(context).size.height.toInt() + 5,
        charId: widget.charID,
        charName: widget.charName,
        charImage: widget.charImage ?? '',
        charDesc: widget.charDesc,
        messages: requestMessages,
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

  void _injectCharacterTapBridgeScript() {
    final controller = _webViewController;
    if (controller == null) return;

    const script = '''
(() => {
  try {
    if (window.__inzoneCharacterTapBridgeInstalled) return;
    window.__inzoneCharacterTapBridgeInstalled = true;

    const keywordMatch = (value) => {
      if (!value || typeof value !== 'string') return false;
      const text = value.toLowerCase();
      return text.includes('character') || text.includes('avatar') || text.includes('profile') || text.includes('agent');
    };

    const isVisible = (el, win) => {
      if (!el || !el.getBoundingClientRect) return false;
      const style = win.getComputedStyle ? win.getComputedStyle(el) : null;
      if (!style) return true;
      if (style.display === 'none' || style.visibility === 'hidden' || style.opacity === '0') {
        return false;
      }
      const rect = el.getBoundingClientRect();
      return rect.width > 0 && rect.height > 0;
    };

    const isGameStartMenuVisible = (doc, win) => {
      const candidates = doc.querySelectorAll('button, [role="button"], div, span, a');
      let found = 0;
      const labels = new Set(['easy', 'medium', 'hard']);

      for (let i = 0; i < candidates.length; i += 1) {
        const el = candidates[i];
        if (!isVisible(el, win)) continue;
        const text = ((el.innerText || el.textContent || '') + '').toLowerCase().trim();
        if (!labels.has(text)) continue;

        const rect = el.getBoundingClientRect();
        if (rect.width >= 80 && rect.height >= 30) {
          found += 1;
        }
        if (found >= 2) return true;
      }

      return false;
    };

    const isStartMenuButton = (el) => {
      if (!el) return false;
      const text = ((el.innerText || el.textContent || '') + '').toLowerCase().trim();
      if (!text) return false;
      return text === 'easy' || text === 'medium' || text === 'hard';
    };

    const isCharacterElement = (el, win) => {
      if (!el || !el.getAttribute) return false;

      const attrs = [
        el.getAttribute('data-testid'),
        el.getAttribute('id'),
        el.getAttribute('class'),
        el.getAttribute('aria-label'),
        el.getAttribute('title'),
        el.getAttribute('alt'),
      ];

      for (const attr of attrs) {
        if (keywordMatch(attr)) return true;
      }

      if (el.tagName === 'IMG' && keywordMatch(el.alt || '')) return true;
      if (el.tagName === 'BUTTON' && keywordMatch(el.getAttribute('aria-label') || '')) return true;

      const style = win.getComputedStyle ? win.getComputedStyle(el) : null;
      const width = el.offsetWidth || 0;
      const height = el.offsetHeight || 0;
      const likelyCircleSize = width >= 24 && width <= 140 && Math.abs(width - height) <= 16;
      const borderRadius = style ? (style.borderRadius || '').toLowerCase() : '';
      const looksCircular = borderRadius.includes('50%') || borderRadius.includes('999') || borderRadius.includes('100%');
      const isFloating = style && (style.position === 'fixed' || style.position === 'absolute' || style.position === 'sticky');
      const isDraggableCursor = style && ((style.cursor || '').includes('grab') || (style.cursor || '').includes('move'));
      const draggableHint = !!(el.getAttribute('draggable') || '').toString().toLowerCase().includes('true');
      const hasTouchActionNone = style && (style.touchAction || '').toLowerCase().includes('none');

      if (!likelyCircleSize) return false;

      if ((isFloating && (isDraggableCursor || draggableHint || hasTouchActionNone)) && looksCircular) {
        return true;
      }

      if (keywordMatch(el.getAttribute('data-testid') || '') && isFloating && looksCircular) {
        return true;
      }

      return false;
    };

    let lastTapMs = 0;

    const sendTap = () => {
      const now = Date.now();
      if (now - lastTapMs < 400) return;
      lastTapMs = now;

      if (window.InzoneCharacterTap && window.InzoneCharacterTap.postMessage) {
        window.InzoneCharacterTap.postMessage('character_tap');
      }
    };

    const getEventPoint = (event) => {
      if (!event) return null;
      if (typeof event.clientX === 'number' && typeof event.clientY === 'number') {
        return { x: event.clientX, y: event.clientY };
      }
      const touch = (event.changedTouches && event.changedTouches[0])
        || (event.touches && event.touches[0]);
      if (touch && typeof touch.clientX === 'number' && typeof touch.clientY === 'number') {
        return { x: touch.clientX, y: touch.clientY };
      }
      return null;
    };

    const isInGameCircleZone = (event, win) => {
      const point = getEventPoint(event);
      if (!point) return false;

      const vw = win.innerWidth || 0;
      const vh = win.innerHeight || 0;
      if (vw <= 0 || vh <= 0) return false;

      const zoneLeft = 0;
      const zoneTop = 52;
      const zoneRight = Math.min(190, vw * 0.5);
      const zoneBottom = Math.min(250, vh * 0.42);

      return point.x >= zoneLeft &&
        point.x <= zoneRight &&
        point.y >= zoneTop &&
        point.y <= zoneBottom;
    };

    const inspect = (doc, win, event) => {
      if (isGameStartMenuVisible(doc, win)) return;

      let node = event.target;
      let depth = 0;
      while (node && depth < 8) {
        if (isStartMenuButton(node)) return;
        if (isCharacterElement(node, win)) {
          sendTap();
          break;
        }
        node = node.parentElement;
        depth += 1;
      }

      if (isInGameCircleZone(event, win)) {
        sendTap();
      }
    };

    const maybeAttachDirectCircleListeners = (doc, win) => {
      if (isGameStartMenuVisible(doc, win)) return;

      const nodes = doc.querySelectorAll('img, button, div, span, canvas');
      const vw = win.innerWidth || 0;
      const vh = win.innerHeight || 0;

      for (let i = 0; i < nodes.length; i += 1) {
        const node = nodes[i];
        if (!isVisible(node, win)) continue;
        if (!isCharacterElement(node, win)) continue;

        const rect = node.getBoundingClientRect();
        const nearTopLeft = rect.left < vw * 0.5 && rect.top < vh * 0.5;
        if (!nearTopLeft) continue;

        if (node.__inzoneTapBound) continue;
        node.__inzoneTapBound = true;

        node.addEventListener('click', () => {
          if (!isGameStartMenuVisible(doc, win)) sendTap();
        }, true);

        node.addEventListener('touchend', () => {
          if (!isGameStartMenuVisible(doc, win)) sendTap();
        }, true);

        node.addEventListener('pointerup', () => {
          if (!isGameStartMenuVisible(doc, win)) sendTap();
        }, true);
      }
    };

    const findTopLeftCharacterElement = (doc, win) => {
      if (!doc || !doc.querySelectorAll) return null;

      const nodes = doc.querySelectorAll('img, button, div, span, canvas');
      const vw = win.innerWidth || 0;
      const vh = win.innerHeight || 0;

      let best = null;
      let bestScore = Number.POSITIVE_INFINITY;

      for (let i = 0; i < nodes.length; i += 1) {
        const node = nodes[i];
        if (!isVisible(node, win)) continue;
        if (!isCharacterElement(node, win)) continue;

        const rect = node.getBoundingClientRect();
        const nearTopLeft = rect.left < vw * 0.5 && rect.top < vh * 0.5;
        if (!nearTopLeft) continue;

        const score = (Math.max(0, rect.left) * 2) + Math.max(0, rect.top);
        if (score < bestScore) {
          best = node;
          bestScore = score;
        }
      }

      return best;
    };

    const ensureCharacterSelectorBadge = (doc, win) => {
      if (!doc || !doc.body) return;

      if (isGameStartMenuVisible(doc, win)) {
        if (doc.__inzoneSelectorBadge && doc.__inzoneSelectorBadge.parentElement) {
          doc.__inzoneSelectorBadge.parentElement.removeChild(doc.__inzoneSelectorBadge);
        }
        doc.__inzoneSelectorBadge = null;
        return;
      }

      const anchor = findTopLeftCharacterElement(doc, win);
      if (!anchor) {
        if (doc.__inzoneSelectorBadge) {
          doc.__inzoneSelectorBadge.style.display = 'none';
        }
        return;
      }

      const rect = anchor.getBoundingClientRect();
      const badgeSize = 24;
      const gap = 4;
      const left = Math.max(8, rect.right - badgeSize * 0.5 + gap);
      const top = Math.max(8, rect.bottom - badgeSize * 0.6);

      let badge = doc.__inzoneSelectorBadge;
      if (!badge) {
        badge = doc.createElement('button');
        badge.type = 'button';
        badge.setAttribute('aria-label', 'Change character');
        badge.setAttribute('title', 'Change character');
        badge.style.position = 'fixed';
        badge.style.width = badgeSize + 'px';
        badge.style.height = badgeSize + 'px';
        badge.style.borderRadius = '999px';
        badge.style.border = '2px solid #DFF7FF';
        badge.style.background = '#16C2E3';
        badge.style.color = '#FFFFFF';
        badge.style.display = 'flex';
        badge.style.alignItems = 'center';
        badge.style.justifyContent = 'center';
        badge.style.fontSize = '16px';
        badge.style.fontWeight = '700';
        badge.style.lineHeight = '1';
        badge.style.padding = '0';
        badge.style.margin = '0';
        badge.style.cursor = 'pointer';
        badge.style.zIndex = '2147483647';
        badge.style.boxShadow = '0 2px 10px rgba(0,0,0,0.22)';
        badge.style.userSelect = 'none';
        badge.style.webkitUserSelect = 'none';
        badge.textContent = '⌄';

        const trigger = (event) => {
          if (event) {
            if (event.preventDefault) event.preventDefault();
            if (event.stopPropagation) event.stopPropagation();
          }
          sendTap();
        };

        badge.addEventListener('click', trigger, true);
        badge.addEventListener('pointerup', trigger, true);
        badge.addEventListener('touchend', trigger, true);

        doc.body.appendChild(badge);
        doc.__inzoneSelectorBadge = badge;
      }

      badge.style.display = 'flex';
      badge.style.left = left + 'px';
      badge.style.top = top + 'px';
    };

    const installBridgeForDocument = (doc, win) => {
      if (!doc || !win) return;
      if (doc.__inzoneDocBridgeInstalled) return;
      doc.__inzoneDocBridgeInstalled = true;

      const handler = (event) => inspect(doc, win, event);
      doc.addEventListener('click', handler, true);
      doc.addEventListener('pointerup', handler, true);
      doc.addEventListener('touchend', handler, true);

      maybeAttachDirectCircleListeners(doc, win);
      ensureCharacterSelectorBadge(doc, win);
    };

    const installBridgesRecursively = () => {
      installBridgeForDocument(document, window);

      const iframes = document.querySelectorAll('iframe');
      for (let i = 0; i < iframes.length; i += 1) {
        const iframe = iframes[i];
        try {
          const subWin = iframe.contentWindow;
          const subDoc = subWin ? subWin.document : null;
          if (!subWin || !subDoc) continue;
          installBridgeForDocument(subDoc, subWin);
          maybeAttachDirectCircleListeners(subDoc, subWin);
          ensureCharacterSelectorBadge(subDoc, subWin);
        } catch (_) {
          // Cross-origin iframe, ignore.
        }
      }

      ensureCharacterSelectorBadge(document, window);
    };

    installBridgesRecursively();
    window.setInterval(installBridgesRecursively, 1200);
  } catch (_) {}
})();
''';

    controller.runJavaScript(script).catchError((_) {});

    const gameOverTextScript = '''
(() => {
  try {
    if (window.__inzoneGameOverTextBridgeInstalled) return;
    window.__inzoneGameOverTextBridgeInstalled = true;

    const inzoneStats = {
      action: '',
      score: null,
      level: null,
      turns: null,
      coins: null,
      distance: null,
      gameResult: '',
    };

    const toNumericString = (value) => {
      if (value === null || value === undefined) return null;
      const num = Number(value);
      if (!Number.isFinite(num)) return null;
      if (Math.abs(num - Math.round(num)) < 0.001) return String(Math.round(num));
      return String(Number(num.toFixed(2)));
    };

    const extractStatsFromText = (text) => {
      if (!text || typeof text !== 'string') {
        return {
          score: null,
          level: null,
          turns: null,
          coins: null,
          distance: null,
        };
      }

      const lower = text.toLowerCase();
      const scoreMatch =
        lower.match(/(?:score|points|best)\s*[:=-]?\s*(\d[\d,]*)/i) ||
        lower.match(/(\d[\d,]*)\s*(?:score|points|best)\b/i);
      const levelMatch =
        lower.match(/(?:level|stage)\s*[:=-]?\s*(\d+)/i) ||
        lower.match(/level\s*(\d+)\s*cleared/i);
      const turnsMatch = lower.match(/(?:turns|moves)\s*[:=-]?\s*(\d+)/i);
      const coinsMatch = lower.match(/coins?\s*[:=-]?\s*(\d[\d,]*)/i);
      const distanceMatch = lower.match(/distance\s*[:=-]?\s*(\d[\d,]*)/i);

      return {
        score: scoreMatch ? String(scoreMatch[1]).replace(/,/g, '') : null,
        level: levelMatch ? String(levelMatch[1]) : null,
        turns: turnsMatch ? String(turnsMatch[1]) : null,
        coins: coinsMatch ? String(coinsMatch[1]).replace(/,/g, '') : null,
        distance: distanceMatch ? String(distanceMatch[1]).replace(/,/g, '') : null,
      };
    };

    const applyExtractedStats = (stats) => {
      if (!stats || typeof stats !== 'object') return;
      if (stats.score !== null && stats.score !== undefined) inzoneStats.score = String(stats.score);
      if (stats.level !== null && stats.level !== undefined) inzoneStats.level = String(stats.level);
      if (stats.turns !== null && stats.turns !== undefined) inzoneStats.turns = String(stats.turns);
      if (stats.coins !== null && stats.coins !== undefined) inzoneStats.coins = String(stats.coins);
      if (stats.distance !== null && stats.distance !== undefined) inzoneStats.distance = String(stats.distance);
    };

    const updateStatsFromGamePayload = (gameData) => {
      if (!gameData || typeof gameData !== 'object') return;

      if (gameData.action) inzoneStats.action = String(gameData.action);
      if (gameData.gameResult) inzoneStats.gameResult = String(gameData.gameResult);

      const scoreValue =
        gameData.userScore ??
        gameData.user_score ??
        gameData.score ??
        gameData.points ??
        gameData.finalScore ??
        gameData.final_score ??
        gameData.totalScore ??
        gameData.total_score ??
        gameData.currentScore ??
        gameData.current_score ??
        gameData.totalPoints ??
        gameData.total_points ??
        gameData.tileScore ??
        gameData.tile_score ??
        gameData.highScore ??
        gameData.high_score ??
        gameData.bestScore ??
        gameData.best_score;
      const levelValue =
        gameData.level ??
        gameData.currentLevel ??
        gameData.current_level ??
        gameData.completedLevel ??
        gameData.completed_level ??
        gameData.levelReached ??
        gameData.level_reached ??
        gameData.stage ??
        gameData.round ??
        gameData.lvl;
      const turnsValue = gameData.turns ?? gameData.moves ?? gameData.moveCount ?? gameData.move_count;
      const coinsValue = gameData.coins ?? gameData.coinCount ?? gameData.coin_count;
      const distanceValue = gameData.distance ?? gameData.maxDistance ?? gameData.max_distance;

      const scoreText = toNumericString(scoreValue);
      const levelText = toNumericString(levelValue);
      const turnsText = toNumericString(turnsValue);
      const coinsText = toNumericString(coinsValue);
      const distanceText = toNumericString(distanceValue);

      if (scoreText !== null) inzoneStats.score = scoreText;
      if (levelText !== null) inzoneStats.level = levelText;
      if (turnsText !== null) inzoneStats.turns = turnsText;
      if (coinsText !== null) inzoneStats.coins = coinsText;
      if (distanceText !== null) inzoneStats.distance = distanceText;

      const textCandidates = [
        gameData.text,
        gameData.message,
        gameData.title,
        gameData.subtitle,
        gameData.status,
        gameData.actionLabel,
        gameData.action_label,
      ];

      for (let i = 0; i < textCandidates.length; i += 1) {
        const extracted = extractStatsFromText(
          textCandidates[i] === undefined || textCandidates[i] === null
              ? ''
              : String(textCandidates[i]),
        );
        applyExtractedStats(extracted);
      }

      if (
        inzoneStats.action === 'game_end' ||
        inzoneStats.gameResult === 'completed' ||
        inzoneStats.gameResult === 'failed'
      ) {
        collect();
      }
    };

    const looksLikeGameStatsKey = (key) => {
      if (!key || typeof key !== 'string') return false;
      const k = key.toLowerCase();
      return (
        k.includes('score') ||
        k.includes('point') ||
        k.includes('coin') ||
        k.includes('distance') ||
        k.includes('turn') ||
        k.includes('move') ||
        k.includes('level') ||
        k.includes('stage') ||
        k.includes('result') ||
        k === 'action'
      );
    };

    const collectStatsFromAnyObject = (obj) => {
      if (!obj || typeof obj !== 'object') return;

      if (Array.isArray(obj)) {
        for (let i = 0; i < obj.length; i += 1) {
          collectStatsFromAnyObject(obj[i]);
        }
        return;
      }

      const normalized = {};

      const entries = Object.entries(obj);
      for (let i = 0; i < entries.length; i += 1) {
        const pair = entries[i];
        const key = String(pair[0]);
        const value = pair[1];
        const keyLower = key.toLowerCase();

        if (value && typeof value === 'object') {
          collectStatsFromAnyObject(value);
          continue;
        }

        if (typeof value === 'string') {
          if (
            keyLower.includes('text') ||
            keyLower.includes('message') ||
            keyLower.includes('title') ||
            keyLower.includes('status')
          ) {
            applyExtractedStats(extractStatsFromText(value));
          }
        }

        if (!looksLikeGameStatsKey(keyLower)) continue;
        normalized[keyLower] = value;
      }

      updateStatsFromGamePayload({
        action: normalized.action,
        gameResult: normalized.gameresult ?? normalized.result,
        userScore:
          normalized.userscore ??
          normalized.user_score ??
          normalized.score ??
          normalized.finalscore ??
          normalized.final_score ??
          normalized.totalscore ??
          normalized.total_score ??
          normalized.tilescore ??
          normalized.tile_score ??
          normalized.highscore ??
          normalized.high_score ??
          normalized.bestscore ??
          normalized.best_score ??
          normalized.points,
        level:
          normalized.level ??
          normalized.currentlevel ??
          normalized.current_level,
        stage: normalized.stage ?? normalized.round ?? normalized.lvl,
        turns: normalized.turns,
        moves: normalized.moves ?? normalized.movecount ?? normalized.move_count,
        coins: normalized.coins ?? normalized.coincount ?? normalized.coin_count,
        distance: normalized.distance ?? normalized.maxdistance ?? normalized.max_distance,
      });
    };

    const consumeParsedTelemetry = (parsed) => {
      if (!parsed) return;

      const updates = Array.isArray(parsed) ? parsed : [parsed];
      for (let i = 0; i < updates.length; i += 1) {
        const update = updates[i];
        if (!update || typeof update !== 'object') continue;

        collectStatsFromAnyObject(update);

        const updateType = String(update.type || '').toUpperCase();
        if (updateType === 'GAMEPLAY') {
          const gameData = update.data && update.data.game ? update.data.game : null;
          updateStatsFromGamePayload(gameData);
        }
      }
    };

    const tryParseAndCaptureTelemetry = (rawPayload) => {
      if (rawPayload === null || rawPayload === undefined) return;

      if (typeof rawPayload === 'object') {
        consumeParsedTelemetry(rawPayload);
        return;
      }

      if (typeof rawPayload !== 'string') return;

      applyExtractedStats(extractStatsFromText(rawPayload));

      const lowerPayload = rawPayload.toLowerCase();
      if (
        !lowerPayload.includes('gameplay') &&
        !lowerPayload.includes('game_end') &&
        !lowerPayload.includes('score') &&
        !lowerPayload.includes('level') &&
        !lowerPayload.includes('stage') &&
        !lowerPayload.includes('finalscore') &&
        !lowerPayload.includes('final_score') &&
        !lowerPayload.includes('totalscore') &&
        !lowerPayload.includes('total_score') &&
        !lowerPayload.includes('tilescore') &&
        !lowerPayload.includes('tile_score') &&
        !lowerPayload.includes('highscore') &&
        !lowerPayload.includes('high_score') &&
        !lowerPayload.includes('bestscore') &&
        !lowerPayload.includes('best_score') &&
        !lowerPayload.includes('userscore') &&
        !lowerPayload.includes('user_score') &&
        !lowerPayload.includes('coins') &&
        !lowerPayload.includes('distance') &&
        !lowerPayload.includes('result')
      ) {
        return;
      }

      try {
        const parsed = JSON.parse(rawPayload);
        consumeParsedTelemetry(parsed);
      } catch (_) {
        // ignore non-json payloads
      }
    };

    const tryParseGameplayFromConsoleText = (text) => {
      if (!text || typeof text !== 'string') return;
      if (!text.toLowerCase().includes('websocket') || !text.toLowerCase().includes('gameplay')) return;

      const bracketIndex = text.indexOf('[');
      if (bracketIndex < 0) return;

      const payloadText = text.substring(bracketIndex);
      tryParseAndCaptureTelemetry(payloadText);
    };

    const decodeMaybeBinaryPayload = (payload) => {
      try {
        if (typeof payload === 'string') return payload;
        if (payload instanceof ArrayBuffer) {
          return new TextDecoder('utf-8').decode(new Uint8Array(payload));
        }
        if (ArrayBuffer.isView(payload)) {
          return new TextDecoder('utf-8').decode(
            new Uint8Array(payload.buffer, payload.byteOffset, payload.byteLength)
          );
        }
      } catch (_) {}
      return null;
    };

    const patchConsoleMethod = (targetConsole, methodName) => {
      if (!targetConsole) return;

      const original = targetConsole[methodName];
      if (typeof original !== 'function') return;

      const patchFlag = '__inzonePatched_' + methodName;
      if (targetConsole[patchFlag]) return;
      targetConsole[patchFlag] = true;

      targetConsole[methodName] = function() {
        try {
          for (let i = 0; i < arguments.length; i += 1) {
            const arg = arguments[i];
            if (typeof arg === 'string') {
              tryParseGameplayFromConsoleText(arg);
              tryParseAndCaptureTelemetry(arg);
            } else if (arg && typeof arg === 'object') {
              tryParseAndCaptureTelemetry(arg);
            }
          }
        } catch (_) {}
        return original.apply(this, arguments);
      };
    };

    const patchWindowTelemetry = (targetWin) => {
      if (!targetWin) return;

      try {
        const wsProto = targetWin.WebSocket && targetWin.WebSocket.prototype;
        if (wsProto && !wsProto.__inzonePatchedSend) {
          wsProto.__inzonePatchedSend = true;
          const originalSend = wsProto.send;
          wsProto.send = function(data) {
            try {
              if (typeof data === 'string') {
                tryParseAndCaptureTelemetry(data);
              } else if (data && typeof data === 'object') {
                const decoded = decodeMaybeBinaryPayload(data);
                if (decoded && typeof decoded === 'string' && decoded.length > 0) {
                  tryParseAndCaptureTelemetry(decoded);
                }
                tryParseAndCaptureTelemetry(data);
              }
            } catch (_) {}
            return originalSend.apply(this, arguments);
          };
        }
      } catch (_) {}

      try {
        patchConsoleMethod(targetWin.console, 'log');
        patchConsoleMethod(targetWin.console, 'info');
        patchConsoleMethod(targetWin.console, 'debug');
      } catch (_) {}
    };

    const scanAndPatchAllReachableWindows = () => {
      const queue = [window];
      const visited = [];

      while (queue.length > 0) {
        const currentWin = queue.shift();
        if (!currentWin) continue;
        if (visited.includes(currentWin)) continue;
        visited.push(currentWin);

        patchWindowTelemetry(currentWin);

        try {
          const frames = currentWin.frames || [];
          for (let i = 0; i < frames.length; i += 1) {
            const child = frames[i];
            if (child) queue.push(child);
          }
        } catch (_) {}

        try {
          const iframes = currentWin.document ? currentWin.document.querySelectorAll('iframe') : [];
          for (let i = 0; i < iframes.length; i += 1) {
            const iframeWin = iframes[i].contentWindow;
            if (iframeWin) queue.push(iframeWin);
          }
        } catch (_) {}
      }
    };

    scanAndPatchAllReachableWindows();
    window.setInterval(scanAndPatchAllReachableWindows, 1000);

    window.addEventListener('message', (event) => {
      try {
        const data = event ? event.data : null;
        if (data === null || data === undefined) return;

        if (typeof data === 'string') {
          applyExtractedStats(extractStatsFromText(data));
          tryParseAndCaptureTelemetry(data);
          return;
        }

        if (typeof data === 'object') {
          tryParseAndCaptureTelemetry(data);
          try {
            applyExtractedStats(extractStatsFromText(JSON.stringify(data)));
          } catch (_) {}
        }
      } catch (_) {}
    }, true);

    let lastPayload = '';

    const isVisible = (el, win) => {
      if (!el || !el.getBoundingClientRect) return false;
      const style = win.getComputedStyle ? win.getComputedStyle(el) : null;
      if (style) {
        if (style.display === 'none' || style.visibility === 'hidden' || style.opacity === '0') {
          return false;
        }
      }
      const rect = el.getBoundingClientRect();
      return rect.width > 0 && rect.height > 0;
    };

    function collect() {
      const doc = document;
      const nodes = doc.querySelectorAll('h1, h2, h3, h4, h5, h6, p, span, div, button, strong');
      const lines = [];

      for (let i = 0; i < nodes.length; i += 1) {
        const el = nodes[i];
        if (!isVisible(el, window)) continue;
        const text = (el.innerText || el.textContent || '').replace(/\s+/g, ' ').trim();
        if (!text) continue;
        lines.push(text);
        if (lines.length >= 20) break;
      }

      const fullText = lines.join(' | ');
      const lower = fullText.toLowerCase();

      const gameOverLikely =
        lower.includes('game over') ||
        lower.includes('you lost') ||
        lower.includes('try again') ||
        lower.includes('play again') ||
        lower.includes('final score') ||
        lower.includes('score:') ||
        lower.includes('level complete') ||
        lower.includes('you win');

      const scoreMatch =
        lower.match(/(?:score|points|best)\s*[:=-]?\s*(\d[\d,]*)/i) ||
        lower.match(/(\d[\d,]*)\s*(?:score|points|best)\b/i);
      const levelMatch =
        lower.match(/(?:level|stage)\s*[:=-]?\s*(\d+)/i) ||
        lower.match(/level\s*(\d+)\s*cleared/i);
      const turnsMatch = lower.match(/(?:turns|moves)\s*[:=-]?\s*(\d+)/i);

      const payload = {
        text: fullText.substring(0, 600),
        title: (document && document.title ? String(document.title) : '').substring(0, 120),
        url: (window && window.location ? String(window.location.href) : '').substring(0, 200),
        score: inzoneStats.score || (scoreMatch ? String(scoreMatch[1]).replace(/,/g, '') : null),
        level: inzoneStats.level || (levelMatch ? levelMatch[1] : null),
        turns: inzoneStats.turns || (turnsMatch ? turnsMatch[1] : null),
        coins: inzoneStats.coins,
        distance: inzoneStats.distance,
        action: inzoneStats.action || null,
        gameResult: inzoneStats.gameResult || null,
        gameOverLikely,
      };

      const normalized = JSON.stringify(payload);
      if (normalized !== lastPayload) {
        lastPayload = normalized;
        try {
          window.__inzoneLastInzoneGameOverPayload = normalized;
        } catch (_) {}
        if (window.InzoneGameOverText && window.InzoneGameOverText.postMessage) {
          window.InzoneGameOverText.postMessage(normalized);
        }
      }
    }

    collect();
    window.setInterval(collect, 1200);
  } catch (_) {}
})();
''';

  controller.runJavaScript(gameOverTextScript).catchError((_) {});
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

        // Treat > 0.95 or == 1.0 as full screen (no bottom sheet UI)
        if (percentageValue > 0.95 || percentageValue == 1.0) {
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
      // Keep system UI visible so content isn't blocked by dynamic island
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
        overlays: SystemUiOverlay.values,
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
              child: _buildContent(isBottomSheet: true),
            ),
          ),
        ),
      );
    }

    return Container(
      color: Colors.black.withValues(alpha: 0.8),
      child: SafeArea(
        child: _buildContent(isBottomSheet: false),
      ),
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
