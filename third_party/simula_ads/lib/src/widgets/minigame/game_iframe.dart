import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb, listEquals;
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
  final ValueChanged<int>? onCoinSpend;
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
    this.onCoinSpend,
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
  String? _characterId;
  String? _characterName;
  String? _characterImage;
  String? _characterDesc;
  bool _delegateChar = true;

  bool get _isChessGame => widget.gameId.toLowerCase().contains('chess');

  @override
  void initState() {
    super.initState();
    _characterId = widget.charID;
    _characterName = widget.charName;
    _characterImage = widget.charImage;
    _characterDesc = widget.charDesc;
    _delegateChar = widget.delegateChar;
    if (!kIsWeb) {
      _initWebView();
    }
  }

  void updateCharacterContext({
    required String charID,
    required String charName,
    String? charImage,
    String? charDesc,
    required bool delegateChar,
  }) {
    _characterId = charID;
    _characterName = charName;
    _characterImage = charImage;
    _characterDesc = charDesc;
    _delegateChar = delegateChar;

    if (!mounted) return;

    _updateOverlay();
    _injectCharacterUpdate();
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

  void _injectCharacterUpdate() {
    final controller = _webViewController;
    if (controller == null || _iframeUrl == null) return;

    final charData = {
        'charID': _characterId ?? widget.charID,
        'charName': _characterName ?? widget.charName,
        'charImage': _characterImage ?? widget.charImage ?? '',
        'charDesc': _characterDesc ?? widget.charDesc ?? '',
        'delegateChar': _delegateChar,
    };

    final json = jsonEncode(charData);
    controller.runJavaScript('''
  (() => {
    try {
      const payload = $json;
      const message = { type: 'INZONE_CHARACTER_UPDATE', data: payload };

      try {
        window.__inzoneCharacterContext = payload;
      } catch (_) {}

      try {
        window.postMessage(message, '*');
      } catch (_) {}

      try {
        window.dispatchEvent(new CustomEvent('INZONE_CHARACTER_UPDATE', { detail: payload }));
      } catch (_) {}

      const iframes = document.querySelectorAll('iframe');
      for (let i = 0; i < iframes.length; i += 1) {
        const frame = iframes[i];
        try {
          if (frame.contentWindow) {
            frame.contentWindow.postMessage(message, '*');
          }
        } catch (_) {
          // Ignore cross-origin frame access failures.
        }
      }
    } catch(_) {}
  })();
  ''').catchError((_) {});
  }

  @override
  void didUpdateWidget(GameIframe oldWidget) {
    super.didUpdateWidget(oldWidget);

    final characterContextChanged = oldWidget.charID != widget.charID ||
        oldWidget.charName != widget.charName ||
        oldWidget.charImage != widget.charImage ||
        oldWidget.charDesc != widget.charDesc ||
        oldWidget.delegateChar != widget.delegateChar;

    if (characterContextChanged) {
      _characterId = widget.charID;
      _characterName = widget.charName;
      _characterImage = widget.charImage;
      _characterDesc = widget.charDesc;
      _delegateChar = widget.delegateChar;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _updateOverlay();
          _injectCharacterUpdate();
        }
      });
    }

    if (oldWidget.playableHeight != widget.playableHeight) {
      setState(() {
        _currentHeight = null;
        _lastBottomSheetState = null;
      });
      _updateOverlay();
    }

    final messagesChanged = !listEquals(oldWidget.messages, widget.messages);
    if (messagesChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _updateOverlay();
        }
      });
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
        final avatarRelayTop =
          isBottomSheet ? screenSize.height - containerHeight + 60 : safeTop + 56;
        final touchBlockerTop =
            isBottomSheet ? screenSize.height - containerHeight + 8 : safeTop;

        return Stack(
          children: [
            if (widget.onCharacterTap != null)
              Positioned(
                top: avatarRelayTop,
                left: 8,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onCharacterTap,
                  child: const SizedBox(
                    width: 72,
                    height: 72,
                  ),
                ),
              ),
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

  int? _parseCoinSpendPayload(dynamic raw) {
    if (raw == null) return null;
    if (raw is num) {
      return raw.isFinite ? raw.round() : null;
    }
    if (raw is String) {
      final text = raw.trim();
      if (text.isEmpty) return null;
      try {
        final decoded = jsonDecode(text);
        if (decoded is num) return decoded.isFinite ? decoded.round() : null;
        if (decoded is Map) {
          final value = decoded['coins'] ?? decoded['coinAmount'] ?? decoded['amount'];
          if (value is num) return value.isFinite ? value.round() : null;
          if (value is String) return int.tryParse(value.replaceAll(',', ''));
        }
      } catch (_) {
        return int.tryParse(text.replaceAll(',', ''));
      }
    }
    return null;
  }

  String _buildLabeledTelemetryText(Map<String, dynamic> payload) {
    final normalizedPayload = Map<String, dynamic>.from(payload);

    String? normalizeChessTitle(String? value) {
      if (!_isChessGame || value == null) return value;
      final source = value.trim().toLowerCase();
      if (source.isEmpty) return null;

      if (source.contains('victory') ||
          source.contains('win') ||
          source.contains('won') ||
          source.contains('checkmate')) {
        return 'Victory';
      }
      if (source.contains('defeat') ||
          source.contains('lose') ||
          source.contains('loss') ||
          source.contains('lost')) {
        return 'Defeat';
      }
      if (source.contains('draw') ||
          source.contains('stalemate') ||
          source.contains('tie')) {
        return 'Draw';
      }

      return value;
    }

    String? firstNonEmpty(List<dynamic> values) {
      for (final value in values) {
        if (value == null) continue;
        final text = value.toString().trim();
        if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
      }
      return null;
    }

    if (_isChessGame) {
      normalizedPayload['title'] = normalizeChessTitle(
        firstNonEmpty([
          normalizedPayload['title'],
          normalizedPayload['resultTitle'],
          normalizedPayload['result_title'],
          normalizedPayload['result'],
          normalizedPayload['outcome'],
          normalizedPayload['status'],
          normalizedPayload['winner'],
        ]),
      );

      final difficulty = firstNonEmpty([
        normalizedPayload['difficulty'],
        normalizedPayload['levelName'],
        normalizedPayload['level_name'],
        normalizedPayload['aiDifficulty'],
        normalizedPayload['ai_difficulty'],
      ]);
      if (difficulty != null) {
        normalizedPayload['difficulty'] = difficulty;
      }

      final moves = firstNonEmpty([
        normalizedPayload['moves'],
        normalizedPayload['moveCount'],
        normalizedPayload['move_count'],
        normalizedPayload['turns'],
        normalizedPayload['ply'],
      ]);
      if (moves != null) {
        normalizedPayload['moves'] = moves;
      }
    }

    final buffer = StringBuffer();

    void append(String key, String label) {
      final value = normalizedPayload[key]?.toString().trim() ?? '';
      if (value.isEmpty || value.toLowerCase() == 'null') return;
      if (buffer.isNotEmpty) buffer.write(' | ');
      buffer.write('$label: $value');
    }

    final text = normalizedPayload['text']?.toString().trim() ?? '';
    if (text.isNotEmpty) buffer.write(text);

    append('score', 'Score');
    append('level', 'Level');
    append('difficulty', 'Difficulty');
    append('moves', 'Moves');
    append('captures', 'Captures');
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
    const isChessGame = ${_isChessGame ? 'true' : 'false'};
    const normalizeChessTitle = (value) => {
      if (!value || typeof value !== 'string') return null;
      const lower = value.toLowerCase();
      if (lower.includes('victory') || lower.includes('win') || lower.includes('won') || lower.includes('checkmate')) return 'Victory';
      if (lower.includes('defeat') || lower.includes('lose') || lower.includes('loss') || lower.includes('lost')) return 'Defeat';
      if (lower.includes('draw') || lower.includes('stalemate') || lower.includes('tie')) return 'Draw';
      return null;
    };
    const extractDifficulty = (value) => {
      if (!value || typeof value !== 'string') return null;
      const lower = value.toLowerCase();
      const tokens = (' ' + lower.replace(/[^a-z]+/g, ' ') + ' ');
      if (tokens.includes(' easy ')) return 'Easy';
      if (tokens.includes(' medium ')) return 'Medium';
      if (tokens.includes(' hard ')) return 'Hard';
      return null;
    };
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
        const nodes = doc.querySelectorAll('h1, h2, h3, h4, h5, h6, p, span, div, button, strong, td, th, li');
        for (let i = 0; i < nodes.length; i += 1) {
          const el = nodes[i];
          if (!isVisible(el)) continue;
          const text = (el.innerText || el.textContent || '').replace(/s+/g, ' ').trim();
          if (!text) continue;
          lines.push(text);
          if (lines.length >= 90) return;
        }
      };

      collectFromDocument(document);

      if (lines.length < 90) {
        const iframes = document.querySelectorAll('iframe');
        for (let i = 0; i < iframes.length; i += 1) {
          const iframe = iframes[i];
          try {
            const subDoc = iframe.contentDocument || (iframe.contentWindow ? iframe.contentWindow.document : null);
            if (!subDoc) continue;
            collectFromDocument(subDoc);
            if (lines.length >= 90) break;
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

      const extractLabeledStatFromDocument = (doc, labelPattern) => {
        if (!doc || !doc.querySelectorAll) return null;

        const parseNumberFromText = (text) => {
          if (!text || typeof text !== 'string') return null;
          const match = text.match(/\b(d{1,6})\b/);
          if (!match) return null;
          return String(match[1]);
        };

        const nodes = doc.querySelectorAll('h1, h2, h3, h4, h5, h6, p, span, div, button, strong, td, th, li');
        const labelToken = new RegExp('(?:^|\\b)(?:' + labelPattern + ')(?:\\b)', 'i');
        const labelWithValue = new RegExp(labelPattern + '\\s*[:=-]?\\s*(\\d{1,6})', 'i');
        const valueBeforeLabel = new RegExp('(\\d{1,6})\\s*' + labelPattern, 'i');

        for (let i = 0; i < nodes.length; i += 1) {
          const el = nodes[i];
          if (!isVisible(el)) continue;
          const text = (el.innerText || el.textContent || '').replace(/s+/g, ' ').trim();
          if (!text) continue;

          const labeled = text.match(labelWithValue) || text.match(valueBeforeLabel);
          if (labeled && labeled[1]) {
            const parsed = parseNumberFromText(labeled[1]);
            if (parsed !== null) return parsed;
          }

          if (!labelToken.test(text.toLowerCase()) || /d/.test(text)) continue;

          const parent = el.parentElement;
          if (parent) {
            const parentText = (parent.innerText || parent.textContent || '').replace(/s+/g, ' ').trim();
            const parentMatch = parentText.match(labelWithValue) || parentText.match(valueBeforeLabel);
            if (parentMatch && parentMatch[1]) {
              const parsed = parseNumberFromText(parentMatch[1]);
              if (parsed !== null) return parsed;
            }

            const children = parent.children || [];
            for (let c = 0; c < children.length; c += 1) {
              const child = children[c];
              if (child === el) continue;
              const childText = (child.innerText || child.textContent || '').replace(/s+/g, ' ').trim();
              const parsed = parseNumberFromText(childText);
              if (parsed !== null) return parsed;
            }
          }

          const prev = el.previousElementSibling;
          if (prev) {
            const prevText = (prev.innerText || prev.textContent || '').replace(/s+/g, ' ').trim();
            const parsed = parseNumberFromText(prevText);
            if (parsed !== null) return parsed;
          }

          const next = el.nextElementSibling;
          if (next) {
            const nextText = (next.innerText || next.textContent || '').replace(/s+/g, ' ').trim();
            const parsed = parseNumberFromText(nextText);
            if (parsed !== null) return parsed;
          }
        }

        return null;
      };

      const extractStatFromTextBlob = (text, labelPattern) => {
        if (!text || typeof text !== 'string') return null;
        const normalized = text.replace(/s+/g, ' ').trim();
        if (!normalized) return null;

        const labeledAfter = new RegExp('["\\']?(?:' + labelPattern + ')["\\']?\\s*[:=-]?\\s*["\\']?(\\d{1,6})', 'i').exec(normalized);
        if (labeledAfter && labeledAfter[1]) return String(labeledAfter[1]);

        const labeledBefore = new RegExp('(\\d{1,6})\\s*(?:' + labelPattern + ')', 'i').exec(normalized);
        if (labeledBefore && labeledBefore[1]) return String(labeledBefore[1]);

        return null;
      };

      const collectWholeDocumentText = () => {
        const chunks = [];
        try {
          if (document && document.body) {
            chunks.push(String(document.body.innerText || document.body.textContent || ''));
          }
        } catch (_) {}

        const iframes = document.querySelectorAll('iframe');
        for (let i = 0; i < iframes.length; i += 1) {
          const iframe = iframes[i];
          try {
            const subDoc = iframe.contentDocument || (iframe.contentWindow ? iframe.contentWindow.document : null);
            if (!subDoc || !subDoc.body) continue;
            chunks.push(String(subDoc.body.innerText || subDoc.body.textContent || ''));
          } catch (_) {
            // Cross-origin iframe; cannot inspect.
          }
        }

        return chunks.join(' | ').replace(/s+/g, ' ').trim();
      };

      const extractLabeledStatAcrossReachableDocs = (labelPattern) => {
        let value = extractLabeledStatFromDocument(document, labelPattern);
        if (value !== null) return value;

        const iframes = document.querySelectorAll('iframe');
        for (let i = 0; i < iframes.length; i += 1) {
          const iframe = iframes[i];
          try {
            const subDoc = iframe.contentDocument || (iframe.contentWindow ? iframe.contentWindow.document : null);
            if (!subDoc) continue;
            value = extractLabeledStatFromDocument(subDoc, labelPattern);
            if (value !== null) return value;
          } catch (_) {
            // Cross-origin iframe; cannot inspect.
          }
        }

        return null;
      };

      const findStatsInObjectGraph = () => {
        const queue = [];
        const seen = new Set();
        let foundScore = null;
        let foundLevel = null;
        let foundMoves = null;
        let foundCaptures = null;
        let foundTitle = null;
        let foundDifficulty = null;

        const pushCandidate = (obj) => {
          if (!obj || typeof obj !== 'object') return;
          if (seen.has(obj)) return;
          seen.add(obj);
          queue.push(obj);
        };

        pushCandidate(window);

        const hardLimit = 700;
        let inspected = 0;

        while (queue.length > 0 && inspected < hardLimit && (foundScore === null || foundLevel === null || foundMoves === null || foundCaptures === null || foundTitle === null || foundDifficulty === null)) {
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

            if (foundMoves === null && (lowerKey.includes('move') || lowerKey.includes('turn'))) {
              // Some chess engines expose a move list array; its length is the real move count.
              if (Array.isArray(value) && value.length > 0) {
                foundMoves = String(value.length);
              } else {
                // Fallback for scalar counters like moveCount/turns/ply when history arrays are absent.
                const parsed = extractNumber(value);
                if (parsed !== null && parsed !== '0') foundMoves = parsed;
              }
            }

            if (foundCaptures === null && (lowerKey.includes('capture') || lowerKey.includes('taken'))) {
              const parsed = extractNumber(value);
              if (parsed !== null && parsed !== '0') foundCaptures = parsed;
            }

            if (foundTitle === null && (lowerKey.includes('title') || lowerKey.includes('result') || lowerKey.includes('outcome') || lowerKey.includes('status') || lowerKey.includes('winner'))) {
              if (typeof value === 'string') {
                const titleText = value.trim();
                if (titleText) foundTitle = titleText;
              }
            }

            if (foundDifficulty === null && lowerKey.includes('difficulty')) {
              if (typeof value === 'string') {
                const difficultyText = extractDifficulty(value);
                if (difficultyText) foundDifficulty = difficultyText;
              }
            }

            if (value && typeof value === 'object') {
              pushCandidate(value);
            } else if (typeof value === 'string') {
              if (foundScore === null) {
                const scoreInText = value.match(/(?:score|points|best)s*[:=-]?s*(d[d,]*)/i) || value.match(/(d[d,]*)s*(?:score|points|best)\b/i);
                if (scoreInText) foundScore = String(scoreInText[1]).replace(/,/g, '');
              }
              if (foundLevel === null) {
                const levelInText = value.match(/(?:level|stage)s*[:=-]?s*(d+)/i) || value.match(/levels*(d+)s*cleared/i);
                if (levelInText) foundLevel = String(levelInText[1]);
              }
              if (foundMoves === null) {
                const movesInText = value.match(/(?:moves?|turns?)s*[:=-]?s*(d+)/i) || value.match(/(d+)s*(?:moves?|turns?)\b/i);
                if (movesInText) foundMoves = String(movesInText[1]);
              }
              if (foundCaptures === null) {
                const capturesInText = value.match(/(?:captures?|captured|pieces?s*captured)s*[:=-]?s*(d+)/i) || value.match(/(d+)s*(?:captures?|pieces?s*captured)\b/i);
                if (capturesInText) foundCaptures = String(capturesInText[1]);
              }
              if (foundTitle === null) {
                const titleInText = normalizeChessTitle(value);
                if (titleInText) foundTitle = titleInText;
              }
              if (foundDifficulty === null) {
                const difficultyInText = extractDifficulty(value);
                if (difficultyInText) foundDifficulty = difficultyInText;
              }
            }
          }
        }

        return { score: foundScore, level: foundLevel, moves: foundMoves, captures: foundCaptures, title: foundTitle, difficulty: foundDifficulty };
      };

      const findStatsInStorage = () => {
        let storageScore = null;
        let storageLevel = null;
        let storageMoves = null;
        let storageCaptures = null;
        let storageTitle = null;
        let storageDifficulty = null;

        const inspectStorage = (storage) => {
          if (!storage) return;
          for (let i = 0; i < storage.length; i += 1) {
            const k = storage.key(i);
            if (!k) continue;
            const lk = k.toLowerCase();
            const v = storage.getItem(k) || '';

            if (storageScore === null && (lk.includes('score') || v.toLowerCase().includes('score'))) {
              const match = v.match(/(?:score|points|best)s*[:=-]?s*(d[d,]*)/i) || v.match(/(d[d,]*)s*(?:score|points|best)\b/i);
              if (match) storageScore = String(match[1]).replace(/,/g, '');
            }

            if (storageLevel === null && (lk.includes('level') || v.toLowerCase().includes('level'))) {
              const match = v.match(/(?:level|stage)s*[:=-]?s*(d+)/i) || v.match(/levels*(d+)s*cleared/i);
              if (match) storageLevel = String(match[1]);
            }

            if (storageMoves === null && (lk.includes('move') || lk.includes('turn') || v.toLowerCase().includes('move') || v.toLowerCase().includes('turn'))) {
              const match = v.match(/(?:moves?|turns?)s*[:=-]?s*(d+)/i) || v.match(/(d+)s*(?:moves?|turns?)\b/i);
              if (match) storageMoves = String(match[1]);
            }

            if (storageCaptures === null && (lk.includes('capture') || v.toLowerCase().includes('capture'))) {
              const match = v.match(/(?:captures?|captured|pieces?s*captured)s*[:=-]?s*(d+)/i) || v.match(/(d+)s*(?:captures?|pieces?s*captured)\b/i);
              if (match) storageCaptures = String(match[1]);
            }

            if (storageTitle === null && (lk.includes('title') || lk.includes('result') || lk.includes('outcome') || lk.includes('status') || lk.includes('winner') || v.toLowerCase().includes('victory') || v.toLowerCase().includes('defeat') || v.toLowerCase().includes('draw'))) {
              const title = normalizeChessTitle(v);
              if (title) storageTitle = title;
            }

            if (storageDifficulty === null && (lk.includes('difficulty') || v.toLowerCase().includes('easy') || v.toLowerCase().includes('medium') || v.toLowerCase().includes('hard'))) {
              const difficulty = extractDifficulty(v);
              if (difficulty) storageDifficulty = difficulty;
            }
          }
        };

        try { inspectStorage(window.localStorage); } catch (_) {}
        try { inspectStorage(window.sessionStorage); } catch (_) {}

        return { score: storageScore, level: storageLevel, moves: storageMoves, captures: storageCaptures, title: storageTitle, difficulty: storageDifficulty };
      };

      const scoreMatch =
        lower.match(/(?:score|points|best)s*[:=-]?s*(d[d,]*)/i) ||
        lower.match(/(d[d,]*)s*(?:score|points|best)\b/i);
      const levelMatch =
        lower.match(/(?:level|stage)s*[:=-]?s*(d+)/i) ||
        lower.match(/levels*(d+)s*cleared/i);
      const movesMatch =
        lower.match(/(?:moves?|turns?|move[_s-]?count|movecount|ply|plies|full[_s-]?moves?|half[_s-]?moves?)s*[:=-]?s*(d+)/i) ||
        lower.match(/(d+)s*(?:moves?|turns?|ply|plies|full[_s-]?moves?|half[_s-]?moves?)\b/i) ||
        lower.match(/moves*#?s*(d+)/i);
      const capturesMatch =
        lower.match(/(?:captures?|captured|pieces?s*captured)s*[:=-]?s*(d+)/i) ||
        lower.match(/(d+)s*(?:captures?|pieces?s*captured)\b/i);
      const wholeDocText = collectWholeDocumentText();
      const chessTitleMatch = normalizeChessTitle(fullText) || normalizeChessTitle(wholeDocText);
      const chessDifficulty = extractDifficulty(fullText) || extractDifficulty(wholeDocText);
      const wholeDocMoves = extractStatFromTextBlob(wholeDocText, 'moves?|turns?|move_count|movecount|ply|plies|number\\s*of\\s*moves|moves?\\s*made|total\\s*moves?|move\\s*number');
      const wholeDocCaptures = extractStatFromTextBlob(wholeDocText, 'captures?|captured|capture_count|pieces?[_\\s-]?captured');
      const layoutMoves = extractLabeledStatAcrossReachableDocs('moves?|turns?|move_count|movecount|ply|plies|full\\s*moves?|half\\s*moves?|number\\s*of\\s*moves|moves?\\s*made|total\\s*moves?|move\\s*number');
      const layoutCaptures = extractLabeledStatAcrossReachableDocs('captures?|captured|pieces?\\s*captured');
      const graphStats = findStatsInObjectGraph();
      const storageStats = findStatsInStorage();
      const resolvedScore =
        scoreMatch ? String(scoreMatch[1]).replace(/,/g, '') :
        (graphStats.score !== null ? graphStats.score : storageStats.score);
      const resolvedMoves = isChessGame
        ? (movesMatch
            ? String(movesMatch[1])
            : (layoutMoves !== null
                ? layoutMoves
            : (wholeDocMoves !== null
              ? wholeDocMoves
              : (graphStats.moves !== null ? graphStats.moves : storageStats.moves))))
        : null;
      const resolvedCaptures = isChessGame
        ? (capturesMatch
            ? String(capturesMatch[1])
            : (layoutCaptures !== null
                ? layoutCaptures
            : (wholeDocCaptures !== null
              ? wholeDocCaptures
              : (graphStats.captures !== null ? graphStats.captures : storageStats.captures))))
        : null;

      const toInt = (value) => {
        if (value === null || value === undefined) return null;
        const parsed = Number(String(value).replace(/,/g, '').trim());
        if (!Number.isFinite(parsed)) return null;
        return Math.round(parsed);
      };

      let normalizedMoves = resolvedMoves;
      if (isChessGame && normalizedMoves !== null) {
        const movesValue = toInt(normalizedMoves);
        const capturesValue = toInt(resolvedCaptures);
        const explicitMovesInVisibleText = fullText.match(/\bmoves?s*[:=-]?s*(d{1,6})\b/i);
        const explicitMovesValue = explicitMovesInVisibleText ? toInt(explicitMovesInVisibleText[1]) : null;

        if (movesValue !== null) {
          if (explicitMovesValue !== null && explicitMovesValue > movesValue) {
            normalizedMoves = String(explicitMovesValue);
          } else if (capturesValue !== null && capturesValue > 0) {
            // Some engines expose a zero-based terminal move index (N-1) right at game end.
            normalizedMoves = String(movesValue + 1);
          }
        }
      }
      // Prefer explicit UI labels first, then whole-doc stats, then object/storage state for chess moves.

      return {
        text: fullText.substring(0, 800),
        score: resolvedScore,
        level:
          levelMatch ? String(levelMatch[1]) :
          (graphStats.level !== null ? graphStats.level : storageStats.level),
        moves: normalizedMoves,
        turns: normalizedMoves,
        captures: resolvedCaptures,
        title: isChessGame
          ? (chessTitleMatch
              ? chessTitleMatch
              : (graphStats.title !== null ? graphStats.title : storageStats.title))
          : null,
        difficulty: isChessGame
          ? (chessDifficulty
              ? chessDifficulty
              : (graphStats.difficulty !== null ? graphStats.difficulty : storageStats.difficulty))
          : null,
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
      moves: isChessGame
        ? ((live.moves != null && live.moves !== '') ? live.moves : (cached && cached.moves ? String(cached.moves) : null))
        : null,
      captures: isChessGame
        ? ((live.captures != null && live.captures !== '') ? live.captures : (cached && cached.captures ? String(cached.captures) : null))
        : null,
      difficulty: isChessGame
        ? ((live.difficulty != null && live.difficulty !== '') ? live.difficulty : (cached && cached.difficulty ? String(cached.difficulty) : null))
        : null,
      turns: (live.turns != null && live.turns !== '') ? live.turns : (cached && cached.turns ? String(cached.turns) : null),
      coins: cached && cached.coins ? String(cached.coins) : null,
      distance: cached && cached.distance ? String(cached.distance) : null,
      action: cached && cached.action ? String(cached.action) : null,
      title: isChessGame
        ? (normalizeChessTitle((live.title != null && live.title !== '') ? String(live.title) : (cached && cached.title ? String(cached.title) : '')) || ((live.title != null && live.title !== '') ? String(live.title) : (cached && cached.title ? String(cached.title) : null)))
        : (cached && cached.title ? String(cached.title) : null),
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _overlayEntry?.markNeedsBuild();
      }
    });
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
                final finalText =
                    _buildLabeledTelemetryText(decoded.cast<String, dynamic>());
                if (finalText.isNotEmpty) {
                  _lastGameOverTextSnapshot = finalText;
                  widget.onGameOverText?.call(finalText);
                }
              }
            } catch (_) {}
          },
        )
        ..addJavaScriptChannel(
          'InzoneCoinSpend',
          onMessageReceived: (message) {
            final coins = _parseCoinSpendPayload(message.message);
            if (coins != null && coins > 0) {
              widget.onCoinSpend?.call(coins);
            }
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
              _injectCoinSpendBridgeScript();
              _injectCharacterUpdate();
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

    final script = '''
(() => {
  try {
    const isChessGame = ${_isChessGame ? 'true' : 'false'};
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

    const extractLabeledStatFromDocument = (doc, labelPattern) => {
      if (!doc || !doc.querySelectorAll) return null;

      const parseNumberFromText = (text) => {
        if (!text || typeof text !== 'string') return null;
        const match = text.match(/\b(d{1,6})\b/);
        if (!match) return null;
        return String(match[1]);
      };

      const nodes = doc.querySelectorAll('h1, h2, h3, h4, h5, h6, p, span, div, button, strong');
      const labelToken = new RegExp('(?:^|\\b)(?:' + labelPattern + ')(?:\\b)', 'i');
      const labelWithValue = new RegExp(labelPattern + '\\s*[:=-]?\\s*(\\d{1,6})', 'i');
      const valueBeforeLabel = new RegExp('(\\d{1,6})\\s*' + labelPattern, 'i');

      for (let i = 0; i < nodes.length; i += 1) {
        const el = nodes[i];
        if (!isVisible(el, window)) continue;
        const text = (el.innerText || el.textContent || '').replace(/s+/g, ' ').trim();
        if (!text) continue;

        const labeled = text.match(labelWithValue) || text.match(valueBeforeLabel);
        if (labeled && labeled[1]) {
          const parsed = parseNumberFromText(labeled[1]);
          if (parsed !== null) return parsed;
        }

        if (!labelToken.test(text.toLowerCase()) || /d/.test(text)) continue;

        const parent = el.parentElement;
        if (parent) {
          const parentText = (parent.innerText || parent.textContent || '').replace(/s+/g, ' ').trim();
          const parentMatch = parentText.match(labelWithValue) || parentText.match(valueBeforeLabel);
          if (parentMatch && parentMatch[1]) {
            const parsed = parseNumberFromText(parentMatch[1]);
            if (parsed !== null) return parsed;
          }

          const children = parent.children || [];
          for (let c = 0; c < children.length; c += 1) {
            const child = children[c];
            if (child === el) continue;
            const childText = (child.innerText || child.textContent || '').replace(/s+/g, ' ').trim();
            const parsed = parseNumberFromText(childText);
            if (parsed !== null) return parsed;
          }
        }

        const prev = el.previousElementSibling;
        if (prev) {
          const prevText = (prev.innerText || prev.textContent || '').replace(/s+/g, ' ').trim();
          const parsed = parseNumberFromText(prevText);
          if (parsed !== null) return parsed;
        }

        const next = el.nextElementSibling;
        if (next) {
          const nextText = (next.innerText || next.textContent || '').replace(/s+/g, ' ').trim();
          const parsed = parseNumberFromText(nextText);
          if (parsed !== null) return parsed;
        }
      }

      return null;
    };

    const extractLabeledStatAcrossReachableDocs = (labelPattern) => {
      let value = extractLabeledStatFromDocument(document, labelPattern);
      if (value !== null) return value;

      const iframes = document.querySelectorAll('iframe');
      for (let i = 0; i < iframes.length; i += 1) {
        const iframe = iframes[i];
        try {
          const subDoc = iframe.contentDocument || (iframe.contentWindow ? iframe.contentWindow.document : null);
          if (!subDoc) continue;
          value = extractLabeledStatFromDocument(subDoc, labelPattern);
          if (value !== null) return value;
        } catch (_) {
          // Cross-origin iframe; cannot inspect.
        }
      }

      return null;
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

    const isAvatarCandidate = (el, win) => {
      if (!el || !win || !el.getBoundingClientRect) return false;
      if (!isVisible(el, win)) return false;

      const rect = el.getBoundingClientRect();
      const vw = win.innerWidth || 0;
      const vh = win.innerHeight || 0;
      if (vw <= 0 || vh <= 0) return false;

      const nearTopLeft = rect.left < vw * 0.5 && rect.top < vh * 0.5;
      if (!nearTopLeft) return false;

      const width = rect.width || 0;
      const height = rect.height || 0;
      const likelyCircleSize = width >= 24 && width <= 140 && height >= 24 && height <= 140 && Math.abs(width - height) <= 20;
      if (!likelyCircleSize) return false;

      const style = win.getComputedStyle ? win.getComputedStyle(el) : null;
      const borderRadius = style ? (style.borderRadius || '').toLowerCase() : '';
      const looksCircular = borderRadius.includes('50%') || borderRadius.includes('999') || borderRadius.includes('100%');
      if (looksCircular) return true;

      if (el.tagName === 'IMG' || el.tagName === 'BUTTON' || el.tagName === 'DIV') return true;
      return false;
    };

    const applyCharacterToDocument = (doc, win, charData) => {
      if (!doc || !win || !charData) return;

      const name = typeof charData.charName === 'string' ? charData.charName.trim() : '';
      const image = typeof charData.charImage === 'string' ? charData.charImage.trim() : '';

      const nodes = doc.querySelectorAll('img, button, div, span, a, p, h1, h2, h3, h4, h5, h6');
      for (let i = 0; i < nodes.length; i += 1) {
        const node = nodes[i];
        if (!node) continue;

        const attrHints = [
          node.getAttribute ? node.getAttribute('data-testid') : null,
          node.getAttribute ? node.getAttribute('id') : null,
          node.getAttribute ? node.getAttribute('class') : null,
          node.getAttribute ? node.getAttribute('aria-label') : null,
          node.getAttribute ? node.getAttribute('title') : null,
          node.getAttribute ? node.getAttribute('alt') : null,
        ];

        let looksLikeAvatar = false;
        for (let j = 0; j < attrHints.length; j += 1) {
          if (keywordMatch(attrHints[j])) {
            looksLikeAvatar = true;
            break;
          }
        }
        if (!looksLikeAvatar && isAvatarCandidate(node, win)) {
          looksLikeAvatar = true;
        }
        if (!looksLikeAvatar) continue;

        if (image) {
          if (node.tagName === 'IMG') {
            try {
              node.src = image;
              if (node.setAttribute) node.setAttribute('src', image);
            } catch (_) {}
          } else {
            try {
              node.style.backgroundImage = 'url("' + image.replace(/"/g, '\\"') + '")';
              node.style.backgroundSize = 'cover';
              node.style.backgroundPosition = 'center';
              node.style.backgroundRepeat = 'no-repeat';
            } catch (_) {}
          }
        }

        if (name && node.setAttribute) {
          try {
            node.setAttribute('aria-label', name + ' avatar');
          } catch (_) {}
        }
      }

      if (name) {
        const textNodes = doc.querySelectorAll('span, div, p, h1, h2, h3, h4, h5, h6');
        for (let i = 0; i < textNodes.length; i += 1) {
          const node = textNodes[i];
          if (!node || !isVisible(node, win)) continue;
          const text = ((node.textContent || '') + '').trim();
          if (!text || text.length > 42) continue;
          if (!keywordMatch(text)) continue;
          node.textContent = name;
        }
      }
    };

    const applyCharacterRecursively = (charData) => {
      if (!charData || typeof charData !== 'object') return;

      applyCharacterToDocument(document, window, charData);

      const iframes = document.querySelectorAll('iframe');
      for (let i = 0; i < iframes.length; i += 1) {
        const iframe = iframes[i];
        try {
          const subWin = iframe.contentWindow;
          const subDoc = subWin ? subWin.document : null;
          if (!subWin || !subDoc) continue;
          applyCharacterToDocument(subDoc, subWin, charData);
        } catch (_) {
          // Cross-origin iframe, ignore.
        }
      }
    };

    const installCharacterUpdateListeners = (targetWin) => {
      if (!targetWin || targetWin.__inzoneCharacterListenerInstalled) return;
      targetWin.__inzoneCharacterListenerInstalled = true;

      targetWin.addEventListener('message', (event) => {
        try {
          const data = event ? event.data : null;
          if (!data || typeof data !== 'object') return;
          if (data.type !== 'INZONE_CHARACTER_UPDATE' || !data.data) return;
          try { targetWin.__inzoneCharacterContext = data.data; } catch (_) {}
          applyCharacterRecursively(data.data);
        } catch (_) {}
      }, true);

      targetWin.addEventListener('INZONE_CHARACTER_UPDATE', (event) => {
        try {
          const data = event && event.detail ? event.detail : null;
          if (!data || typeof data !== 'object') return;
          try { targetWin.__inzoneCharacterContext = data; } catch (_) {}
          applyCharacterRecursively(data);
        } catch (_) {}
      }, true);
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

    const inspect = (doc, win, event) => {
      if (isGameStartMenuVisible(doc, win)) return;

      let node = event.target;
      let depth = 0;
      while (node && depth < 8) {
        if (isStartMenuButton(node)) return;
        if (isCharacterElement(node, win) || isAvatarCandidate(node, win)) {
          sendTap();
          break;
        }
        node = node.parentElement;
        depth += 1;
      }
    };

    const maybeAttachDirectCircleListeners = (doc, win) => {
      if (isGameStartMenuVisible(doc, win)) return;

      const nodes = doc.querySelectorAll('img, button, div, span, canvas');
      const vw = win.innerWidth || 0;
      const vh = win.innerHeight || 0;

      for (let i = 0; i < nodes.length; i += 1) {
        const node = nodes[i];
        if (!isAvatarCandidate(node, win)) continue;

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
      installCharacterUpdateListeners(window);
      installBridgeForDocument(document, window);

      const iframes = document.querySelectorAll('iframe');
      for (let i = 0; i < iframes.length; i += 1) {
        const iframe = iframes[i];
        try {
          const subWin = iframe.contentWindow;
          const subDoc = subWin ? subWin.document : null;
          if (!subWin || !subDoc) continue;
          installCharacterUpdateListeners(subWin);
          installBridgeForDocument(subDoc, subWin);
          maybeAttachDirectCircleListeners(subDoc, subWin);
        } catch (_) {
          // Cross-origin iframe, ignore.
        }
      }

      try {
        if (window.__inzoneCharacterContext) {
          applyCharacterRecursively(window.__inzoneCharacterContext);
        }
      } catch (_) {}
    };

    installBridgesRecursively();
    window.setInterval(installBridgesRecursively, 1200);
  } catch (_) {}
})();
''';

    controller.runJavaScript(script).catchError((_) {});

    final gameOverTextScript = '''
(() => {
  try {
    const isChessGame = ${_isChessGame ? 'true' : 'false'};
    if (window.__inzoneGameOverTextBridgeInstalled) return;
    window.__inzoneGameOverTextBridgeInstalled = true;

    const inzoneStats = {
      action: '',
      score: null,
      level: null,
      difficulty: null,
      turns: null,
      moves: null,
      captures: null,
      coins: null,
      distance: null,
      title: '',
      gameResult: '',
    };

    const normalizeChessTitle = (value) => {
      if (!value || typeof value !== 'string') return null;
      const lower = value.toLowerCase();
      if (lower.includes('victory') || lower.includes('you win') || lower.includes('win') || lower.includes('won') || lower.includes('checkmate')) return 'Victory';
      if (lower.includes('defeat') || lower.includes('you lose') || lower.includes('lose') || lower.includes('loss') || lower.includes('lost')) return 'Defeat';
      if (lower.includes('draw') || lower.includes('stalemate') || lower.includes('tie')) return 'Draw';
      return null;
    };

    const extractDifficulty = (value) => {
      if (!value || typeof value !== 'string') return null;
      const lower = value.toLowerCase();
      const tokens = (' ' + lower.replace(/[^a-z]+/g, ' ') + ' ');
      if (tokens.includes(' easy ')) return 'Easy';
      if (tokens.includes(' medium ')) return 'Medium';
      if (tokens.includes(' hard ')) return 'Hard';
      return null;
    };

    const toNumericString = (value) => {
      if (value === null || value === undefined) return null;
      const raw = String(value).trim();
      if (!raw) return null;

      const num = Number(raw.replace(/,/g, ''));
      if (!Number.isFinite(num)) return null;
      if (Math.abs(num - Math.round(num)) < 0.001) return String(Math.round(num));
      return String(Number(num.toFixed(2)));
    };

    const toNumericStringLoose = (value) => {
      const direct = toNumericString(value);
      if (direct !== null) return direct;
      if (value === null || value === undefined) return null;

      const raw = String(value).replace(/,/g, ' ');
      const embedded = raw.match(/-?d+(?:.d+)?/);
      if (!embedded) return null;
      return toNumericString(embedded[0]);
    };

    const extractStatsFromText = (text) => {
      if (!text || typeof text !== 'string') {
        return {
          score: null,
          level: null,
          difficulty: null,
          turns: null,
          coins: null,
          distance: null,
        };
      }

      const lower = text.toLowerCase();
      const scoreMatch =
        lower.match(/(?:score|points|best)s*[:=-]?s*(d[d,]*)/i) ||
        lower.match(/(d[d,]*)s*(?:score|points|best)\b/i);
      const levelMatch =
        lower.match(/(?:level|stage)s*[:=-]?s*(d+)/i) ||
        lower.match(/levels*(d+)s*cleared/i);
      const turnsMatch =
        lower.match(/(?:turns|moves?)s*[:=-]?s*(d+)/i) ||
        lower.match(/(?:turns|moves?)D{0,14}(d+)/i);
      const capturesMatch =
        lower.match(/(?:captures?|captured|pieces?s*captured)s*[:=-]?s*(d+)/i) ||
        lower.match(/(d+)s*(?:captures?|pieces?s*captured)\b/i);
      const turnsMatchAlt = lower.match(/(d+)s*(?:turns|moves)\b/i);
      const coinsMatch = lower.match(/coins?s*[:=-]?s*(d[d,]*)/i);
      const distanceMatch = lower.match(/distances*[:=-]?s*(d[d,]*)/i);
      const chessTitle = normalizeChessTitle(text);
      const difficulty = extractDifficulty(text);

      return {
        score: scoreMatch ? String(scoreMatch[1]).replace(/,/g, '') : null,
        level: levelMatch ? String(levelMatch[1]) : null,
        difficulty,
        turns: turnsMatch ? String(turnsMatch[1]) : null,
        moves: turnsMatch ? String(turnsMatch[1]) : (turnsMatchAlt ? String(turnsMatchAlt[1]) : null),
        captures: capturesMatch ? String(capturesMatch[1]).replace(/,/g, '') : null,
        coins: coinsMatch ? String(coinsMatch[1]).replace(/,/g, '') : null,
        distance: distanceMatch ? String(distanceMatch[1]).replace(/,/g, '') : null,
        title: chessTitle,
      };
    };

    const applyExtractedStats = (stats) => {
      if (!stats || typeof stats !== 'object') return;
      if (stats.score !== null && stats.score !== undefined) inzoneStats.score = String(stats.score);
      if (stats.level !== null && stats.level !== undefined) inzoneStats.level = String(stats.level);
      if (stats.difficulty !== null && stats.difficulty !== undefined) inzoneStats.difficulty = String(stats.difficulty);
      if (stats.turns !== null && stats.turns !== undefined) inzoneStats.turns = String(stats.turns);
      if (stats.moves !== null && stats.moves !== undefined) inzoneStats.moves = String(stats.moves);
      if (stats.captures !== null && stats.captures !== undefined) inzoneStats.captures = String(stats.captures);
      if (stats.coins !== null && stats.coins !== undefined) inzoneStats.coins = String(stats.coins);
      if (stats.distance !== null && stats.distance !== undefined) inzoneStats.distance = String(stats.distance);
      if (stats.title) inzoneStats.title = String(stats.title);
    };

    const updateStatsFromGamePayload = (gameData) => {
      if (!gameData || typeof gameData !== 'object') return;

      const findNumericFromKeys = (obj, includeFragments) => {
        if (!obj || typeof obj !== 'object') return null;
        const keys = Object.keys(obj);
        for (let i = 0; i < keys.length; i += 1) {
          const key = keys[i];
          const lowerKey = String(key).toLowerCase();
          let matchesAll = true;
          for (let j = 0; j < includeFragments.length; j += 1) {
            if (!lowerKey.includes(includeFragments[j])) {
              matchesAll = false;
              break;
            }
          }
          if (!matchesAll) continue;

          const text = toNumericStringLoose(obj[key]);
          if (text !== null) return text;
        }
        return null;
      };

      if (gameData.action) inzoneStats.action = String(gameData.action);
      if (gameData.gameResult) inzoneStats.gameResult = String(gameData.gameResult);
      if (isChessGame) {
        const titleFromPayload = normalizeChessTitle(
          String(
            gameData.title ??
            gameData.resultTitle ??
            gameData.result_title ??
            gameData.result ??
            gameData.outcome ??
            gameData.status ??
            gameData.winner ??
            '',
          ),
        );
        if (titleFromPayload) inzoneStats.title = titleFromPayload;
      }

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
      const turnsValue =
        gameData.turns ??
        gameData.moves ??
        gameData.moveCount ??
        gameData.move_count ??
        gameData.totalMoves ??
        gameData.total_moves ??
        gameData.moveNumber ??
        gameData.move_number ??
        gameData.currentMove ??
        gameData.current_move ??
        gameData.numMoves ??
        gameData.num_moves ??
        gameData.numberOfMoves ??
        gameData.number_of_moves ??
        gameData.ply ??
        gameData.plies ??
        gameData.fullMoves ??
        gameData.full_moves ??
        gameData.halfMoves ??
        gameData.half_moves;
      const difficultyValue =
        gameData.difficulty ??
        gameData.levelName ??
        gameData.level_name ??
        gameData.aiDifficulty ??
        gameData.ai_difficulty;
      const capturesValue =
        gameData.captures ??
        gameData.captureCount ??
        gameData.capture_count ??
        gameData.piecesCaptured ??
        gameData.pieces_captured;
      const coinsValue = gameData.coins ?? gameData.coinCount ?? gameData.coin_count;
      const distanceValue = gameData.distance ?? gameData.maxDistance ?? gameData.max_distance;

      const scoreText = toNumericStringLoose(scoreValue);
      const levelText = toNumericStringLoose(levelValue);
      const inferredTurnsText =
        findNumericFromKeys(gameData, ['move']) ||
        findNumericFromKeys(gameData, ['turn']) ||
        findNumericFromKeys(gameData, ['ply']);
      const turnsText = toNumericStringLoose(turnsValue) ?? inferredTurnsText;
      const difficultyText = extractDifficulty(String(difficultyValue ?? ''));
      const capturesText = toNumericStringLoose(capturesValue);
      const coinsText = toNumericStringLoose(coinsValue);
      const distanceText = toNumericStringLoose(distanceValue);

      if (scoreText !== null) inzoneStats.score = scoreText;
      if (levelText !== null) inzoneStats.level = levelText;
      if (turnsText !== null) inzoneStats.turns = turnsText;
      if (turnsText !== null) inzoneStats.moves = turnsText;
      if (difficultyText !== null) inzoneStats.difficulty = difficultyText;
      if (capturesText !== null) inzoneStats.captures = capturesText;
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
        k.includes('capture') ||
        k.includes('level') ||
        k.includes('stage') ||
        k.includes('result') ||
        k.includes('outcome') ||
        k.includes('status') ||
        k.includes('winner') ||
        k.includes('title') ||
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
        difficulty:
          normalized.difficulty ??
          normalized.levelname ??
          normalized.level_name ??
          normalized.aidifficulty ??
          normalized.ai_difficulty,
        stage: normalized.stage ?? normalized.round ?? normalized.lvl,
        turns: normalized.turns,
        moves: normalized.moves ?? normalized.movecount ?? normalized.move_count,
        captures: normalized.captures ?? normalized.capturecount ?? normalized.capture_count ?? normalized.piecescaptured ?? normalized.pieces_captured,
        coins: normalized.coins ?? normalized.coincount ?? normalized.coin_count,
        distance: normalized.distance ?? normalized.maxdistance ?? normalized.max_distance,
        title: normalized.title ?? normalized.resulttitle ?? normalized.result_title ?? normalized.outcome ?? normalized.status ?? normalized.winner,
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
        !lowerPayload.includes('moves') &&
        !lowerPayload.includes('turns') &&
        !lowerPayload.includes('capture') &&
        !lowerPayload.includes('coins') &&
        !lowerPayload.includes('distance') &&
        !lowerPayload.includes('result') &&
        !(isChessGame && (lowerPayload.includes('victory') || lowerPayload.includes('defeat') || lowerPayload.includes('draw')))
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
      const nodes = doc.querySelectorAll('h1, h2, h3, h4, h5, h6, p, span, div, button, strong, td, th, li');
      const lines = [];

      for (let i = 0; i < nodes.length; i += 1) {
        const el = nodes[i];
        if (!isVisible(el, window)) continue;
        const text = (el.innerText || el.textContent || '').replace(/s+/g, ' ').trim();
        if (!text) continue;
        lines.push(text);
        if (lines.length >= 90) break;
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
        lower.match(/(?:score|points|best)s*[:=-]?s*(d[d,]*)/i) ||
        lower.match(/(d[d,]*)s*(?:score|points|best)\b/i);
      const levelMatch =
        lower.match(/(?:level|stage)s*[:=-]?s*(d+)/i) ||
        lower.match(/levels*(d+)s*cleared/i);
      const turnsMatch =
        lower.match(/["']?(?:turns|moves?|move_count|movecount|ply|plies|fulls*moves?|halfs*moves?|numbers*ofs*moves|moves?s*made|totals*moves?|moves*number)["']?s*[:=-#]?s*["']?(d{1,6})/i) ||
        lower.match(/(d{1,6})s*(?:turns|moves?|ply|plies|fulls*moves?|halfs*moves?|totals*moves?)\b/i);
      const capturesMatch =
        lower.match(/["']?(?:captures?|captured|capture_count|pieces?s*captured)["']?s*[:=-]?s*["']?(d{1,6})/i) ||
        lower.match(/(d{1,6})s*(?:captures?|pieces?s*captured)\b/i);
      const layoutMoves = extractLabeledStatAcrossReachableDocs('moves?|turns?|move_count|movecount|ply|plies|full\\s*moves?|half\\s*moves?|number\\s*of\\s*moves|moves?\\s*made|total\\s*moves?|move\\s*number');
      const layoutCaptures = extractLabeledStatAcrossReachableDocs('captures?|captured|capture_count|pieces?\\s*captured');
      const titleMatch = normalizeChessTitle(fullText) || normalizeChessTitle(document && document.title ? String(document.title) : '');
      const difficultyMatch = extractDifficulty(fullText) || extractDifficulty(document && document.title ? String(document.title) : '');
      const resolvedScore = inzoneStats.score || (scoreMatch ? String(scoreMatch[1]).replace(/,/g, '') : null);
      const resolvedMoves = inzoneStats.moves || inzoneStats.turns || (turnsMatch ? turnsMatch[1] : (layoutMoves || null));
      const resolvedCaptures = inzoneStats.captures || (capturesMatch ? capturesMatch[1] : (layoutCaptures || null));

      const toInt = (value) => {
        if (value === null || value === undefined) return null;
        const parsed = Number(String(value).replace(/,/g, '').trim());
        if (!Number.isFinite(parsed)) return null;
        return Math.round(parsed);
      };

      let normalizedMoves = resolvedMoves;
      if (isChessGame && normalizedMoves != null) {
        const movesValue = toInt(normalizedMoves);
        const capturesValue = toInt(resolvedCaptures);
        const explicitMovesInVisibleText = fullText.match(/\bmoves?s*[:=-]?s*(d{1,6})\b/i);
        const explicitMovesValue = explicitMovesInVisibleText ? toInt(explicitMovesInVisibleText[1]) : null;

        if (movesValue !== null) {
          if (explicitMovesValue !== null && explicitMovesValue > movesValue) {
            normalizedMoves = String(explicitMovesValue);
          } else if (capturesValue !== null && capturesValue > 0 && gameOverLikely) {
            // Zero-based move index is common in internal payloads at game completion.
            normalizedMoves = String(movesValue + 1);
          }
        }
      }
      // Keep moves/turns aligned so downstream parsing and logs report the same chess move count.

      const payload = {
        text: fullText.substring(0, 600),
        title: (isChessGame && inzoneStats.title)
          ? inzoneStats.title
          : (titleMatch || (document && document.title ? String(document.title) : '').substring(0, 120)),
        url: (window && window.location ? String(window.location.href) : '').substring(0, 200),
        score: resolvedScore,
        level: inzoneStats.level || (levelMatch ? levelMatch[1] : null),
        difficulty: inzoneStats.difficulty || difficultyMatch,
        moves: normalizedMoves,
        turns: normalizedMoves,
        captures: resolvedCaptures,
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

  void _injectCoinSpendBridgeScript() {
    final controller = _webViewController;
    if (controller == null) return;

    const script = r'''
(() => {
  try {
    if (window.__inzoneCoinSpendBridgeInstalled) return;
    window.__inzoneCoinSpendBridgeInstalled = true;

    const extractCoins = (payload) => {
      if (!payload) return null;
      if (typeof payload === 'number' && Number.isFinite(payload)) return Math.round(payload);
      if (typeof payload === 'string') {
        const cleaned = payload.replace(/,/g, '').trim();
        if (!cleaned) return null;
        const parsed = Number(cleaned);
        return Number.isFinite(parsed) ? Math.round(parsed) : null;
      }
      if (typeof payload === 'object') {
        const value = payload.coins ?? payload.coinAmount ?? payload.amount;
        return extractCoins(value);
      }
      return null;
    };

    const postCoins = (payload) => {
      try {
        if (!window.InzoneCoinSpend || !window.InzoneCoinSpend.postMessage) return;
        const coins = extractCoins(payload);
        if (coins === null) return;
        window.InzoneCoinSpend.postMessage(JSON.stringify({ coins }));
      } catch (_) {}
    };

    window.addEventListener('message', (event) => {
      try {
        const data = event && event.data ? event.data : null;
        if (!data) return;
        const type = typeof data === 'object' ? data.type : null;
        if (type && (type === 'INZONE_COIN_SPEND' || type === 'INZONE_COIN_USED')) {
          postCoins(data);
          return;
        }
        if (typeof data === 'object' && (data.coins || data.coinAmount || data.amount)) {
          postCoins(data);
        }
      } catch (_) {}
    });

    window.addEventListener('INZONE_COIN_SPEND', (event) => {
      try {
        const detail = event && event.detail ? event.detail : event;
        postCoins(detail);
      } catch (_) {}
    });
  } catch (_) {}
})();
''';

    controller.runJavaScript(script).catchError((_) {});
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