import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/types.dart';
import '../config.dart';
import 'dart:io' show Platform;

/// Catalog response containing menu ID and games
class CatalogResponse {
  final String menuId;
  final List<GameData> games;

  CatalogResponse({
    required this.menuId,
    required this.games,
  });
}

/// API client for Simula ad services
class SimulaApiClient {
  final String apiKey;

  SimulaApiClient({
    required this.apiKey,
  }) : assert(apiKey.isNotEmpty, 'API key cannot be empty');

  /// Create a session and return session ID
  Future<String?> createSession({String? primaryUserID, String? idfa, bool? devMode}) async {
    try {
      final params = <String, String>{};
      if (primaryUserID != null && primaryUserID.isNotEmpty) {
        params['ppid'] = primaryUserID;
      }
      
      // Add devMode as query parameter (backend expects string "true" or "false")
      if (devMode != null) {
        params['devMode'] = devMode.toString();
      }

      final queryString = params.isEmpty
          ? ''
          : '?${params.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&')}';
      final url = Uri.parse('${SimulaConfig.apiBaseUrl}/session/create$queryString');

      // Build headers
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      };

      // Include IDFA header if available (only when ATT is authorized)
      if (idfa != null && idfa.isNotEmpty) {
        headers['X-IDFA'] = idfa;
      }

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({}),
      );

      if (response.statusCode == 401) {
        throw Exception(
            'Invalid API key (please check dashboard or contact Simula team for a valid API key)');
      }

      if (!response.statusCode.toString().startsWith('2')) {
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['sessionId'] as String?;
    } catch (e) {
      if (e.toString().contains('Invalid API key')) {
        rethrow;
      }
      return null;
    }
  }

  /// Fetch an ad for feed placement
  Future<FetchAdResponse> fetchAd({
    required String sessionId,
    required String slot,
    required int position,
    required NativeContext context,
    double? width,
  }) async {
    try {
      final requestBody = {
        'session_id': sessionId,
        'slot': slot,
        'position': position,
        'context': context.toJson(),
        if (width != null && width != double.infinity && !width.isNaN) 'width': (width + 5).ceil(), // add 5px to width so it fills container
      };

      final url = Uri.parse('${SimulaConfig.apiBaseUrl}/render_ad/ssp/native');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
          'user-agent': Platform.operatingSystem,
        },
        body: jsonEncode(requestBody),
      );

      if (!response.statusCode.toString().startsWith('2')) {
        throw Exception('HTTP error! status: ${response.statusCode}, body: ${response.body}');
      }

      final responseBody = response.body;

      // If response is empty string, no ad to render
      if (responseBody.isEmpty || responseBody.trim().isEmpty) {
        return FetchAdResponse(error: 'No fill');
      }

      // API returns JSON with ad_id, ad_inserted, ad_format, iframe_url
      final jsonResponse = jsonDecode(responseBody) as Map<String, dynamic>;

      // Check if ad was inserted
      final adInserted = jsonResponse['ad_inserted'] as bool? ?? false;
      if (!adInserted) {
        return FetchAdResponse(error: 'No fill');
      }

      final iframeUrl = jsonResponse['iframe_url'] as String?;
      if (iframeUrl == null || iframeUrl.isEmpty) {
        return FetchAdResponse(error: 'No fill');
      }

      final ad = AdData(
        id: jsonResponse['ad_id'] as String? ?? 'ad_${DateTime.now().millisecondsSinceEpoch}',
        format: 'iframe',
        iframeUrl: iframeUrl,
        adInserted: adInserted,
        adFormat: jsonResponse['ad_format'] as String?,
      );

      return FetchAdResponse(ad: ad);
    } catch (e) {
      if (e is Exception) {
        return FetchAdResponse(error: 'Failed to fetch ad: ${e.toString()}');
      }
      return FetchAdResponse(error: 'Failed to fetch ad: $e');
    }
  }

  /// Track impression for an ad
  Future<void> trackImpression(String adId) async {
    try {
      final url = Uri.parse('${SimulaConfig.apiBaseUrl}/track/engagement/impression/$adId');
      await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
          'user-agent': Platform.operatingSystem,
        },
        body: jsonEncode({}),
      );
    } catch (e) {
      // Silently fail - impression tracking is best effort
    }
  }

  /// Track minigame menu click
  Future<void> trackMenuGameClick({
    required String menuId,
    required String gameName,
  }) async {
    try {
      final url = Uri.parse('${SimulaConfig.apiBaseUrl}/minigames/menu/track/click');
      await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
          'user-agent': Platform.operatingSystem,
        },
        body: jsonEncode({
          'menu_id': menuId,
          'game_name': gameName,
        }),
      );
    } catch (e) {
      // Silently fail - tracking is best effort
    }
  }

  /// Track viewport entry for an ad (when ad enters viewport)
  Future<void> trackViewportEntry(String adId) async {
    try {
      final url = Uri.parse('${SimulaConfig.apiBaseUrl}/track/engagement/viewport_entry/$adId');
      await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
          'user-agent': Platform.operatingSystem,
        },
        body: jsonEncode({
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        }),
      );
    } catch (e) {
      // Silently fail - tracking is best effort
    }
  }

  /// Track viewport exit for an ad (when ad leaves viewport or widget is disposed)
  Future<void> trackViewportExit(String adId) async {
    try {
      final url = Uri.parse('${SimulaConfig.apiBaseUrl}/track/engagement/viewport_exit/$adId');
      await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
          'user-agent': Platform.operatingSystem,
        },
        body: jsonEncode({
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        }),
      );
    } catch (e) {
      // Silently fail - tracking is best effort
    }
  }

  /// Report an ad
  Future<void> reportAd(String adId) async {
    try {
      final url = Uri.parse('${SimulaConfig.apiBaseUrl}/track/engagement/report/$adId');
      await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
          'user-agent': Platform.operatingSystem,
        },
        body: jsonEncode({}),
      );
    } catch (e) {
      // Silently fail - tracking is best effort
    }
  }

  /// Fetch minigame catalog
  Future<CatalogResponse> fetchCatalog() async {
    try {
      final url = Uri.parse('${SimulaConfig.apiBaseUrl}/minigames/catalogv2');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'user-agent': Platform.operatingSystem,
        },
      );

      if (!response.statusCode.toString().startsWith('2')) {
        throw Exception('HTTP error! status: ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      
      // Extract menu_id from response
      final menuId = data['menu_id'] as String? ?? '';
      
      // Handle different response formats: direct catalog list or wrapped in 'data'
      List<dynamic> gamesList;
      if (data['catalog'] != null) {
        // New format: catalog is directly in the response
        final catalog = data['catalog'];
        if (catalog is List) {
          gamesList = catalog;
        } else if (catalog is Map && catalog['data'] != null) {
          // Nested format: catalog.data
          gamesList = catalog['data'] as List<dynamic>;
        } else {
          // Fallback: try data['data'] for backwards compatibility
          gamesList = data['data'] as List<dynamic>? ?? [];
        }
      } else {
        // Fallback: try data['data'] for backwards compatibility
        gamesList = data['data'] as List<dynamic>? ?? [];
      }
      
      final games = gamesList.map((game) => GameData(
        id: game['id'] as String,
        name: game['name'] as String,
        iconUrl: game['icon'] as String? ?? '',
        description: game['description'] as String? ?? '',
        iconFallback: game['iconFallback'] as String?,
      )).toList();

      return CatalogResponse(
        menuId: menuId,
        games: games,
      );
    } catch (e) {
      throw Exception('Failed to fetch catalog: ${e.toString()}');
    }
  }

  /// Initialize a minigame
  Future<MinigameResponse> getMinigame({
    required String gameType,
    required String sessionId,
    required int w,
    required int h,
    required String charId,
    required String charName,
    required String charImage,
    String? charDesc,
    List<Message>? messages,
    bool currencyMode = false,
    bool delegateChar = true,
    String? menuId,
  }) async {
    try {
      final url = Uri.parse('${SimulaConfig.apiBaseUrl}/minigames/init');
      final requestBody = {
        'game_type': gameType,
        'session_id': sessionId,
        'w': w,
        'h': h,
        'char_id': charId,
        'char_name': charName,
        'char_image': charImage,
        if (charDesc != null) 'char_desc': charDesc,
        if (messages != null) 'messages': messages.map((m) => m.toJson()).toList(),
        'currency_mode': currencyMode,
        'delegate_char': delegateChar,
        if (menuId != null) 'menu_id': menuId,
      };

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
          'user-agent': Platform.operatingSystem,
        },
        body: jsonEncode(requestBody),
      );
      
      if (!response.statusCode.toString().startsWith('2')) {
        throw Exception('HTTP error! status: ${response.statusCode}, body: ${response.body}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final adResponse = data['adResponse'] as Map<String, dynamic>;
      
      return MinigameResponse(
        adId: adResponse['ad_id'] as String? ?? '',
        iframeUrl: adResponse['iframe_url'] as String? ?? '',
      );
    } catch (e) {
      throw Exception('Failed to initialize minigame: ${e.toString()}');
    }
  }

  /// Fetch ad for minigame fallback
  Future<String?> fetchAdForMinigame(String adId) async {
    try {
      final url = Uri.parse('${SimulaConfig.apiBaseUrl}/minigames/fallback_ad/$adId');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'user-agent': Platform.operatingSystem, 
        },
      );

      if (!response.statusCode.toString().startsWith('2')) {
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final adResponse = data['adResponse'] as Map<String, dynamic>;
      
      return adResponse['iframe_url'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// Fetch HTML content from an iframe URL
  /// Returns the full HTML document (with shell) that can be directly loaded
  /// This includes the CSS resets to prevent whitespace issues
  Future<String?> fetchIframeHtml(String iframeUrl) async {
    try {
      final url = Uri.parse(iframeUrl);
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'text/html',
          'user-agent': Platform.operatingSystem,
        },
      );

      if (!response.statusCode.toString().startsWith('2')) {
        return null;
      }

      // Return the full HTML response (includes the HTML shell with CSS resets)
      // This ensures no whitespace issues when loading with loadHtmlString()
      return response.body;
    } catch (e) {
      return null;
    }
  }
}

/// Response from fetchAd API
class FetchAdResponse {
  final AdData? ad;
  final String? error;

  FetchAdResponse({this.ad, this.error});
}


/// Response from minigame init API
class MinigameResponse {
  final String adId;
  final String iframeUrl;

  MinigameResponse({
    required this.adId,
    required this.iframeUrl,
  });
}
