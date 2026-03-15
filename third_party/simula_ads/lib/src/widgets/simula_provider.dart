import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../api/api_client.dart';
import '../models/types.dart';
import '../utils/att_status.dart';

/// Simula context value
class SimulaContextValue {
  final String apiKey;
  final String? sessionId;
  final SimulaApiClient apiClient;
  final bool hasPrivacyConsent;

  SimulaContextValue({
    required this.apiKey,
    this.sessionId,
    required this.apiClient,
    required this.hasPrivacyConsent,
  });
}

/// Provider widget that initializes Simula SDK
class SimulaProvider extends StatefulWidget {
  final String apiKey;
  final Widget child;
  final String? primaryUserID;
  /// Privacy consent flag. When false, suppresses collection of PII (primaryUserID, email, userProfile).
  /// Defaults to true for backward compatibility.
  final bool hasPrivacyConsent;
  /// Enable dev mode for the session (for testing/debugging). When enabled, passes `devMode: true` to the session creation API.
  final bool? devMode;

  const SimulaProvider({
    super.key,
    required this.apiKey,
    required this.child,
    this.primaryUserID,
    this.hasPrivacyConsent = true,
    this.devMode,
  });

  @override
  State<SimulaProvider> createState() => _SimulaProviderState();
}

class _SimulaProviderState extends State<SimulaProvider> {
  late SimulaNotifier _notifier;

  @override
  void initState() {
    super.initState();
    // Validate API key
    if (widget.apiKey.isEmpty) {
      throw ArgumentError('SimulaProvider requires a non-empty apiKey');
    }
    
    _initializeWebView();
    final apiClient = SimulaApiClient(
      apiKey: widget.apiKey,
    );
    _notifier = SimulaNotifier(
      apiKey: widget.apiKey,
      apiClient: apiClient,
      hasPrivacyConsent: widget.hasPrivacyConsent,
    );
    _initializeATT();
    _createSession();
  }

  void _initializeWebView() {
    // Initialize webview platform
    // For web, we need webview_flutter_web (should be in dependencies)
    // For mobile (Android/iOS), webview_flutter handles initialization automatically
    if (kIsWeb) {
      // On web, the platform should be initialized by webview_flutter_web
      // If you see errors, ensure webview_flutter_web is in your app's dependencies
      try {
        // WebViewPlatform should be set by webview_flutter_web automatically
        WebViewPlatform.instance;
      } catch (e) {
        // Silently handle WebView platform initialization
      }
    } else {
      // Mobile platforms (Android/iOS) - webview_flutter initializes automatically
      // No action needed, but we can verify it's available
      try {
        WebViewPlatform.instance;
      } catch (e) {
        // Silently handle WebView platform initialization
      }
    }
  }

  /// Initialize ATT status and collect IDFA if authorized
  Future<void> _initializeATT() async {
    final status = await ATTStatus.getAuthorizationStatus();
    _notifier.setATTStatus(status);
    
    // Only collect IDFA if ATT is authorized
    if (status == ATTAuthorizationStatus.authorized) {
      final idfa = await ATTStatus.getIDFA();
      if (idfa != null && idfa.isNotEmpty) {
        _notifier.setIDFA(idfa);
      }
    }
  }

  Future<void> _createSession() async {
    // Only send primaryUserID if privacy consent is granted
    final primaryUserID = _notifier.hasPrivacyConsent ? widget.primaryUserID : null;
    final idfa = _notifier.idfa; // Get IDFA if available
    final sessionId = await _notifier.apiClient.createSession(
      primaryUserID: primaryUserID,
      idfa: idfa,
      devMode: widget.devMode,
    );
    if (mounted && sessionId != null) {
      _notifier.updateSessionId(sessionId);
    }
  }


  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _notifier,
      child: widget.child,
    );
  }
}

/// Notifier for Simula context
class SimulaNotifier extends ChangeNotifier {
  final String apiKey;
  String? sessionId;
  final SimulaApiClient apiClient;
  bool hasPrivacyConsent;
  ATTAuthorizationStatus? attStatus;
  String? idfa;

  // Simple cache: keyed by "slot:position" -> AdData with HTML
  final Map<String, AdData> _adCache = {};
  
  // Height cache: keyed by "slot:position" -> measured height in pixels
  final Map<String, double> _heightCache = {};
  
  // No-fill cache: keyed by "slot:position" -> true if we know there's no fill
  final Set<String> _noFillCache = {};

  SimulaNotifier({
    required this.apiKey,
    this.sessionId,
    required this.apiClient,
    this.hasPrivacyConsent = true,
    this.attStatus,
    this.idfa,
  });

  void updateSessionId(String? newSessionId) {
    sessionId = newSessionId;
    notifyListeners();
    // Prefetch initialization will be triggered by first ad slot when it appears
  }

  /// Update privacy consent status. When changed, existing session may need to be recreated.
  /// If consent is withdrawn mid-session, future API calls will exclude PII.
  void setPrivacyConsent(bool consent) {
    if (hasPrivacyConsent != consent) {
      hasPrivacyConsent = consent;
      notifyListeners();
      // Note: Existing session continues to work, but future calls will respect new consent status
      // If consent is withdrawn and a new session is needed, publisher should handle that
    }
  }

  /// Set ATT authorization status
  void setATTStatus(ATTAuthorizationStatus status) {
    if (attStatus != status) {
      attStatus = status;
      notifyListeners();
    }
  }

  /// Set IDFA (Identifier for Advertisers)
  void setIDFA(String? idfaValue) {
    if (idfa != idfaValue) {
      idfa = idfaValue;
      notifyListeners();
    }
  }

  /// Get cached ad for a specific slot and position
  AdData? getCachedAd(String slot, int position) {
    final key = _getCacheKey(slot, position);
    return _adCache[key];
  }

  /// Check if we know there's no fill for a specific slot and position
  bool hasNoFill(String slot, int position) {
    final key = _getCacheKey(slot, position);
    return _noFillCache.contains(key);
  }

  /// Mark a slot/position as having no fill to prevent refetching
  void cacheNoFill(String slot, int position) {
    final key = _getCacheKey(slot, position);
    _noFillCache.add(key);
  }

  /// Cache an ad for a specific slot and position
  void cacheAd(String slot, int position, AdData ad) {
    final key = _getCacheKey(slot, position);
    _adCache[key] = ad;
  }

  /// Get cached height for a specific slot and position
  double? getCachedHeight(String slot, int position) {
    final key = _getCacheKey(slot, position);
    return _heightCache[key];
  }

  /// Cache height for a specific slot and position
  void cacheHeight(String slot, int position, double height) {
    final key = _getCacheKey(slot, position);
    _heightCache[key] = height;
  }

  /// Fetch an ad and cache it with HTML
  /// Returns the cached ad if available, otherwise fetches and caches it
  Future<AdData?> fetchAndCacheAd({
    required String slot,
    required int position,
    required String sessionId,
    required NativeContext context,
    double? width,
  }) async {
    // Check cache first
    final cached = getCachedAd(slot, position);
    if (cached != null) {
      return cached;
    }

    if (sessionId.isEmpty) {
      return null;
    }

    // Filter context to respect privacy consent
    final filteredContext = context.filterForPrivacy(hasPrivacyConsent);

    try {
      final response = await apiClient.fetchAd(
        sessionId: sessionId,
        slot: slot,
        position: position,
        context: filteredContext,
        width: width,
      );

      if (response.ad != null && (response.ad!.iframeHtml != null || response.ad!.iframeUrl != null)) {
        // If HTML is already present (from "frame" field), use it directly
        // Otherwise, fetch the HTML from the iframe URL
        AdData adWithHtml = response.ad!;
        if (response.ad!.iframeHtml == null && response.ad!.iframeUrl != null) {
          final iframeHtml = await apiClient.fetchIframeHtml(response.ad!.iframeUrl!);
          if (iframeHtml != null) {
            adWithHtml = response.ad!.copyWith(iframeHtml: iframeHtml);
          }
        }
        
        // Cache the ad
        cacheAd(slot, position, adWithHtml);
        
        return adWithHtml;
      } else {
        // No ad available - cache the no-fill state to prevent refetching
        cacheNoFill(slot, position);
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// Clear all cache (e.g., on session change)
  void clearCache() {
    _adCache.clear();
    _noFillCache.clear();
  }

  String _getCacheKey(String slot, int position) => '$slot:$position';
}

/// Hook to access Simula context
SimulaContextValue useSimula(BuildContext context) {
  final notifier = Provider.of<SimulaNotifier>(context, listen: false);
  return SimulaContextValue(
    apiKey: notifier.apiKey,
    sessionId: notifier.sessionId,
    apiClient: notifier.apiClient,
    hasPrivacyConsent: notifier.hasPrivacyConsent,
  );
}
