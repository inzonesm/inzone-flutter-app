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
                  onTap: () {
                    widget.onClose?.call(_currentHeight);
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

    const installBridgeForDocument = (doc, win) => {
      if (!doc || !win) return;
      if (doc.__inzoneDocBridgeInstalled) return;
      doc.__inzoneDocBridgeInstalled = true;

      const handler = (event) => inspect(doc, win, event);
      doc.addEventListener('click', handler, true);
      doc.addEventListener('pointerup', handler, true);
      doc.addEventListener('touchend', handler, true);

      maybeAttachDirectCircleListeners(doc, win);
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
        } catch (_) {
          // Cross-origin iframe, ignore.
        }
      }
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

    const updateStatsFromGamePayload = (gameData) => {
      if (!gameData || typeof gameData !== 'object') return;

      if (gameData.action) inzoneStats.action = String(gameData.action);
      if (gameData.gameResult) inzoneStats.gameResult = String(gameData.gameResult);

      const scoreValue = gameData.userScore ?? gameData.score ?? gameData.points ?? gameData.finalScore;
      const levelValue = gameData.level ?? gameData.stage;
      const turnsValue = gameData.turns ?? gameData.moves;
      const coinsValue = gameData.coins;
      const distanceValue = gameData.distance;

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

        if (!looksLikeGameStatsKey(keyLower)) continue;
        normalized[keyLower] = value;
      }

      updateStatsFromGamePayload({
        action: normalized.action,
        gameResult: normalized.gameresult ?? normalized.result,
        userScore:
          normalized.userscore ??
          normalized.score ??
          normalized.finalscore ??
          normalized.points,
        level: normalized.level,
        stage: normalized.stage,
        turns: normalized.turns,
        moves: normalized.moves,
        coins: normalized.coins,
        distance: normalized.distance,
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

      const lowerPayload = rawPayload.toLowerCase();
      if (
        !lowerPayload.includes('gameplay') &&
        !lowerPayload.includes('game_end') &&
        !lowerPayload.includes('userscore') &&
        !lowerPayload.includes('coins') &&
        !lowerPayload.includes('distance')
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

      const scoreMatch = lower.match(/(?:score|points|best)\s*[:=-]?\s*(\d+)/i);
      const levelMatch = lower.match(/(?:level|stage)\s*[:=-]?\s*(\d+)/i);
      const turnsMatch = lower.match(/(?:turns|moves)\s*[:=-]?\s*(\d+)/i);

      const payload = {
        text: fullText.substring(0, 600),
        title: (document && document.title ? String(document.title) : '').substring(0, 120),
        url: (window && window.location ? String(window.location.href) : '').substring(0, 200),
        score: inzoneStats.score || (scoreMatch ? scoreMatch[1] : null),
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