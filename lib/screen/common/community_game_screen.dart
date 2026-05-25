import 'dart:convert';

import 'package:colorful_safe_area/colorful_safe_area.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:inzone/data/community_game.dart';

class CommunityGameScreen extends StatefulWidget {
  final CommunityGame game;

  const CommunityGameScreen({super.key, required this.game});

  @override
  State<CommunityGameScreen> createState() => _CommunityGameScreenState();
}

class _CommunityGameScreenState extends State<CommunityGameScreen> {
  static const String _fixtureAssetPath = 'assets/html/social_loop_tap_targets.html';

  InAppWebViewController? _controller;
  bool _isLoading = true;
  String _loadError = '';
  late final bool _useLocalFixture;
  late final Future<String> _fixtureHtmlFuture;
  late final String _sessionId;
  late final String _backendBaseUrl;
  late final String? _playerId;
  late final String? _gameKey;

  @override
  void initState() {
    super.initState();
    _useLocalFixture = _isLocalFixtureUrl(widget.game.gameUrl);
    _fixtureHtmlFuture = _useLocalFixture
        ? rootBundle.loadString(_fixtureAssetPath)
        : Future.value('');
    _sessionId = DateTime.now().microsecondsSinceEpoch.toString();
    _backendBaseUrl = _resolveBackendBaseUrl();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid.trim();
    _playerId = (currentUserId != null && currentUserId.isNotEmpty) ? currentUserId : null;
    final key = widget.game.gameKey?.trim();
    _gameKey = key != null && key.isNotEmpty ? key : null;
  }

  bool _isLocalFixtureUrl(String gameUrl) {
    final normalized = gameUrl.trim().toLowerCase();
    return normalized.isEmpty ||
        normalized == 'inzone-test://social-loop' ||
        normalized == 'asset://social-loop-tap-targets';
  }

  String _resolveBackendBaseUrl() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:5000';
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return 'http://127.0.0.1:5000';
    }
  }

  Future<Map<String, dynamic>> _handleSocialLoopAction(
    String action,
    Map<String, dynamic> payload,
  ) async {
    final overrideBaseUrl = _extractBackendBaseUrl(payload);
    final client = _SocialLoopBackendClient(
      baseUrl: overrideBaseUrl ?? _backendBaseUrl,
      gameKey: _gameKey,
    );

    Map<String, dynamic> mergePayload(Map<String, dynamic> extra) {
      return {
        'gameId': widget.game.id,
        'gameName': widget.game.name,
        'gameKey': _gameKey,
        'sessionId': _sessionId,
        'userId': _playerId,
        'playerId': _playerId,
        ...payload,
        ...extra,
      };
    }

    switch (action) {
      case 'getConfig':
        return {
          'success': true,
          'data': {
            'gameId': widget.game.id,
            'gameName': widget.game.name,
            'gameKey': _gameKey,
            'sessionId': _sessionId,
            'userId': _playerId,
            'backendBaseUrl': _backendBaseUrl,
            'fixtureMode': _useLocalFixture,
          },
        };
      case 'openSocialScreen':
        return client.openSocialScreen(mergePayload({}));
      case 'gameState':
        return client.gameState(mergePayload({}));
      case 'dashboard':
        return client.dashboard(mergePayload({}));
      case 'postScore':
        return client.postScore(mergePayload({}));
      case 'sendChallenge':
        return client.sendChallenge(mergePayload({}));
      case 'shareCard':
        return client.shareCard(mergePayload({}));
      case 'openChat':
        return client.openChat(mergePayload({}));
      case 'purchaseCoinTier':
        final coins = (payload['coins'] as num?)?.toInt();
        if (coins == null) {
          throw ArgumentError('coins is required for purchaseCoinTier');
        }
        return client.purchaseCoinTier(coins, mergePayload({'coins': coins}));
      case 'close':
        if (mounted) {
          context.pop();
        }
        return {'success': true};
      default:
        throw ArgumentError('Unknown social loop action: $action');
    }
  }

  String? _extractBackendBaseUrl(Map<String, dynamic> payload) {
    final raw = payload['backendBaseUrl']?.toString().trim();
    if (raw == null || raw.isEmpty) return null;
    return raw;
  }

  String _bridgeInjectionScript() {
    final config = jsonEncode({
      'gameId': widget.game.id,
      'gameName': widget.game.name,
      'gameKey': _gameKey,
      'sessionId': _sessionId,
      'userId': _playerId,
      'backendBaseUrl': _backendBaseUrl,
      'fixtureMode': _useLocalFixture,
      'gameUrl': widget.game.gameUrl,
    });

    return '''
      (function () {
        const config = $config;
        window.__INZONE_SOCIAL_LOOP_CONFIG__ = config;

        if (window.InZoneSDK && window.InZoneSDK.__inzoneInjected) {
          window.InZoneSDK.config = config;
          window.dispatchEvent(new CustomEvent('inzone:sdk-ready', { detail: config }));
          return;
        }

        const callBridge = (action, payload) => {
          if (!window.flutter_inappwebview || !window.flutter_inappwebview.callHandler) {
            return Promise.reject(new Error('InZone bridge is unavailable'));
          }
          return window.flutter_inappwebview.callHandler('socialLoop', {
            action: action,
            payload: payload || {},
          });
        };

        window.InZoneSDK = {
          __inzoneInjected: true,
          config: config,
          getConfig: function () {
            return Promise.resolve(config);
          },
          openSocialScreen: function (payload) {
            return callBridge('openSocialScreen', payload);
          },
          gameState: function (payload) {
            return callBridge('gameState', payload);
          },
          dashboard: function (payload) {
            return callBridge('dashboard', payload);
          },
          postScore: function (payload) {
            return callBridge('postScore', payload);
          },
          sendChallenge: function (payload) {
            return callBridge('sendChallenge', payload);
          },
          shareCard: function (payload) {
            return callBridge('shareCard', payload);
          },
          openChat: function (payload) {
            return callBridge('openChat', payload);
          },
          purchaseCoinTier: function (coins, payload) {
            return callBridge('purchaseCoinTier', Object.assign({ coins: coins }, payload || {}));
          },
          close: function () {
            return callBridge('close', {});
          },
        };

        window.dispatchEvent(new CustomEvent('inzone:sdk-ready', { detail: config }));
      })();
    ''';
  }

  Widget _buildWebView(ThemeData theme, {String? initialHtml}) {
    return Stack(
      children: [
        InAppWebView(
          initialData: initialHtml == null
              ? null
              : InAppWebViewInitialData(
                  data: initialHtml,
                  baseUrl: WebUri('https://inzone.local'),
                  mimeType: 'text/html',
                  encoding: 'utf-8',
                ),
          initialUrlRequest: initialHtml == null
              ? URLRequest(url: WebUri(widget.game.gameUrl))
              : null,
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
          onWebViewCreated: (controller) {
            _controller = controller;
            controller.addJavaScriptHandler(
              handlerName: 'socialLoop',
              callback: (args) async {
                final raw = args.isNotEmpty && args.first is Map
                    ? Map<String, dynamic>.from(args.first as Map)
                    : <String, dynamic>{};
                final action = raw['action']?.toString() ?? '';
                final payload = raw['payload'] is Map
                    ? Map<String, dynamic>.from(raw['payload'] as Map)
                    : <String, dynamic>{};
                return _handleSocialLoopAction(action, payload);
              },
            );
          },
          onLoadStart: (_, __) {
            if (!mounted) return;
            setState(() {
              _isLoading = true;
              _loadError = '';
            });
          },
          onLoadStop: (controller, __) async {
            if (!mounted) return;
            await controller.evaluateJavascript(source: _bridgeInjectionScript());
            if (!mounted) return;
            setState(() {
              _isLoading = false;
            });
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
                  Text(
                    'Loading ${widget.game.name}…',
                    style: theme.textTheme.titleMedium,
                  ),
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
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error Loading Game',
                    style: theme.textTheme.titleLarge,
                  ),
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
    );
  }

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
        body: _useLocalFixture
            ? FutureBuilder<String>(
                future: _fixtureHtmlFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return Center(
                      child: CircularProgressIndicator(color: theme.primaryColor),
                    );
                  }
                  if (snapshot.hasError || !snapshot.hasData) {
                    return Center(
                      child: Text(
                        'Failed to load social loop test page.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    );
                  }
                  return _buildWebView(theme, initialHtml: snapshot.data!);
                },
              )
            : _buildWebView(theme),
      ),
    );
  }
}

class _SocialLoopBackendClient {
  _SocialLoopBackendClient({required this.baseUrl, required this.gameKey});

  final String baseUrl;
  final String? gameKey;

  Future<Map<String, dynamic>> openSocialScreen(Map<String, dynamic> payload) {
    return _postJson('/api/game-sdk/open-social-screen', payload, attachGameKey: false);
  }

  Future<Map<String, dynamic>> gameState(Map<String, dynamic> payload) {
    return _getJson('/api/game-sdk/game-state', payload, attachGameKey: true);
  }

  Future<Map<String, dynamic>> dashboard(Map<String, dynamic> payload) {
    return _getJson('/api/game-sdk/dashboard', payload, attachGameKey: true);
  }

  Future<Map<String, dynamic>> postScore(Map<String, dynamic> payload) {
    return _postJson('/api/game-sdk/post-score', payload, attachGameKey: false);
  }

  Future<Map<String, dynamic>> sendChallenge(Map<String, dynamic> payload) {
    return _postJson('/api/game-sdk/send-challenge', payload, attachGameKey: false);
  }

  Future<Map<String, dynamic>> shareCard(Map<String, dynamic> payload) {
    return _postJson('/api/game-sdk/share-card', payload, attachGameKey: false);
  }

  Future<Map<String, dynamic>> openChat(Map<String, dynamic> payload) {
    return _postJson('/api/game-sdk/open-chat', payload, attachGameKey: false);
  }

  Future<Map<String, dynamic>> purchaseCoinTier(int coins, Map<String, dynamic> payload) {
    return _postJson('/api/game-sdk/coins/tier-$coins', payload, attachGameKey: true);
  }

  Future<Map<String, dynamic>> _getJson(
    String path,
    Map<String, dynamic> payload, {
    required bool attachGameKey,
  }) async {
    final uri = _buildUri(path, payload);
    final response = await http.get(uri, headers: _headers(attachGameKey: attachGameKey));
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> payload, {
    required bool attachGameKey,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final body = Map<String, dynamic>.from(payload);
    if (attachGameKey && gameKey != null && gameKey!.isNotEmpty) {
      body['gameKey'] = gameKey;
    }
    final response = await http.post(
      uri,
      headers: _headers(attachGameKey: attachGameKey),
      body: jsonEncode(body),
    );
    return _decodeResponse(response);
  }

  Uri _buildUri(String path, Map<String, dynamic> payload) {
    final query = Map<String, String>.fromEntries(
      payload.entries
          .where((entry) => entry.value != null)
          .map((entry) => MapEntry(entry.key, entry.value.toString())),
    );
    if (gameKey != null && gameKey!.isNotEmpty) {
      query.putIfAbsent('gameKey', () => gameKey!);
    }
    return Uri.parse('$baseUrl$path').replace(queryParameters: query);
  }

  Map<String, String> _headers({required bool attachGameKey}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (attachGameKey && gameKey != null && gameKey!.isNotEmpty) {
      headers['X-Game-Key'] = gameKey!;
    }
    return headers;
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final body = response.body.trim();
    final decoded = body.isEmpty ? <String, dynamic>{} : jsonDecode(body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errorMessage = decoded is Map<String, dynamic>
          ? decoded['error']?.toString() ?? 'Request failed'
          : 'Request failed';
      throw Exception(errorMessage);
    }
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return <String, dynamic>{'success': true, 'data': decoded};
  }
}
