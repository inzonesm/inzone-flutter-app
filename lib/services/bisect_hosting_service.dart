import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Thrown when the Starbase panel rejects the user's API key.
class BisectAuthException implements Exception {
  final String message;
  const BisectAuthException(this.message);
  @override
  String toString() => message;
}

/// A game server on the user's BisectHosting account (Starbase panel).
class BisectServer {
  final String identifier;
  final String name;
  final String description;

  /// "ip:port" of the default network allocation, when the panel includes it.
  final String? address;

  const BisectServer({
    required this.identifier,
    required this.name,
    required this.description,
    this.address,
  });
}

/// Live resource usage / power state of a BisectHosting server.
class BisectServerResources {
  /// running | starting | stopping | offline
  final String state;
  final double cpuPercent;
  final int memoryBytes;

  const BisectServerResources({
    required this.state,
    required this.cpuPercent,
    required this.memoryBytes,
  });

  bool get isRunning => state == 'running';
}

/// One entry in the in-app "host a game" catalog. [selectorPlan] deep-links
/// straight into BisectHosting's plan selector when known; otherwise the
/// game's marketing/order page is used.
class BisectCatalogEntry {
  final String name;
  final String emoji;
  final String blurb;

  /// Path on www.bisecthosting.com (no leading slash), verified to resolve.
  final String pagePath;
  final String? selectorPlan;
  final String? selectorExtraQuery;

  const BisectCatalogEntry({
    required this.name,
    required this.emoji,
    required this.blurb,
    required this.pagePath,
    this.selectorPlan,
    this.selectorExtraQuery,
  });
}

/// Integration with BisectHosting (game server hosting):
///  - order deep links for the "host your own server" catalog;
///  - the Starbase panel Client API (games.bisecthosting.com) so customers
///    can see and control their own servers in-app with a self-generated
///    `ptlc_` API key (panel: Account -> API Credentials).
///
/// The API key is the user's own credential for their own account; it is kept
/// on-device only (SharedPreferences) and sent solely to the official panel
/// host over HTTPS.
class BisectHostingService {
  BisectHostingService._();

  static const String siteBaseUrl = 'https://www.bisecthosting.com';
  static const String panelBaseUrl = 'https://games.bisecthosting.com';
  static const String panelApiCredentialsHint =
      'games.bisecthosting.com → Account → API Credentials';

  /// Optional promo/affiliate code appended to order links (BisectHosting
  /// affiliate program: activate in the billing panel, 10% recurring).
  /// Leave empty until a code is issued for the InZone account.
  static const String promoCode = '';

  static const String _apiKeyPref = 'bisect_panel_api_key';

  static const Duration _timeout = Duration(seconds: 12);

  // ---------------------------------------------------------------------------
  // Order links ("host your games on it").
  // ---------------------------------------------------------------------------

  /// Curated catalog of hostable games. Slugs verified against
  /// www.bisecthosting.com (2026-07-18); the full list is ~150 games.
  static const List<BisectCatalogEntry> catalog = [
    BisectCatalogEntry(
      name: 'Minecraft: Java Edition',
      emoji: '⛏️',
      blurb: 'The classic — plugins, modpacks & crossplay via Geyser',
      pagePath: 'minecraft-servers',
      selectorPlan: 'minecraft',
      selectorExtraQuery: 'game_version=java',
    ),
    BisectCatalogEntry(
      name: 'Minecraft: Bedrock Edition',
      emoji: '🧱',
      blurb: 'Play with friends on phones, consoles & Windows',
      pagePath: 'minecraft-bedrock-server-hosting',
    ),
    BisectCatalogEntry(
      name: 'Palworld',
      emoji: '🐣',
      blurb: 'Catch pals together on your own island',
      pagePath: 'palworld-server-hosting',
      selectorPlan: 'palworld',
    ),
    BisectCatalogEntry(
      name: 'Valheim',
      emoji: '🪓',
      blurb: 'Viking survival with up to 10 players',
      pagePath: 'valheim-server-hosting',
    ),
    BisectCatalogEntry(
      name: 'Rust',
      emoji: '🔧',
      blurb: 'Hardcore multiplayer survival',
      pagePath: 'rust-server-hosting',
    ),
    BisectCatalogEntry(
      name: 'Terraria',
      emoji: '🌳',
      blurb: '2D sandbox adventures with friends',
      pagePath: 'terraria-server-hosting',
    ),
    BisectCatalogEntry(
      name: 'ARK: Survival Evolved',
      emoji: '🦖',
      blurb: 'Tame dinos on a private island',
      pagePath: 'ark-survival-evolved-server-hosting',
    ),
    BisectCatalogEntry(
      name: 'Project Zomboid',
      emoji: '🧟',
      blurb: 'Co-op zombie apocalypse survival',
      pagePath: 'project-zomboid-server-hosting',
    ),
    BisectCatalogEntry(
      name: 'Enshrouded',
      emoji: '🌫️',
      blurb: 'Survival action RPG for up to 16 players',
      pagePath: 'enshrouded-server-hosting',
    ),
    BisectCatalogEntry(
      name: 'Satisfactory',
      emoji: '🏭',
      blurb: 'Build mega-factories together',
      pagePath: 'satisfactory-server-hosting',
    ),
    BisectCatalogEntry(
      name: 'Factorio',
      emoji: '⚙️',
      blurb: 'The factory must grow — co-op automation',
      pagePath: 'factorio-server-hosting',
    ),
    BisectCatalogEntry(
      name: "Garry's Mod",
      emoji: '🔨',
      blurb: 'Sandbox physics & community game modes',
      pagePath: 'garrys-mod-server-hosting',
    ),
    BisectCatalogEntry(
      name: 'Counter-Strike 2',
      emoji: '🎯',
      blurb: 'Your own competitive or community server',
      pagePath: 'counter-strike-2-server-hosting',
    ),
    BisectCatalogEntry(
      name: '7 Days to Die',
      emoji: '🏚️',
      blurb: 'Zombie horde survival crafting',
      pagePath: '7-days-to-die-server-hosting',
    ),
    BisectCatalogEntry(
      name: 'Sons of the Forest',
      emoji: '🌲',
      blurb: 'Co-op horror survival on your own server',
      pagePath: 'sons-of-the-forest-server-hosting',
    ),
  ];

  /// Where the "Order" button for a catalog entry should send the user:
  /// straight into the plan selector when the plan slug is known, otherwise
  /// the game's hosting page (which carries its own order button).
  static Uri orderUri(BisectCatalogEntry entry) {
    final promo = promoCode.isEmpty ? '' : '&promo_code=$promoCode';
    if (entry.selectorPlan != null) {
      final extra = entry.selectorExtraQuery == null
          ? ''
          : '&${entry.selectorExtraQuery}';
      return Uri.parse(
        '$siteBaseUrl/selector?plan=${entry.selectorPlan}$extra$promo',
      );
    }
    return Uri.parse('$siteBaseUrl/${entry.pagePath}');
  }

  static Uri get allGamesUri => Uri.parse(siteBaseUrl);

  // ---------------------------------------------------------------------------
  // Panel API key storage (on-device only).
  // ---------------------------------------------------------------------------

  static Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_apiKeyPref);
    return (key == null || key.isEmpty) ? null : key;
  }

  static Future<void> setApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyPref, key.trim());
  }

  static Future<void> clearApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_apiKeyPref);
  }

  // ---------------------------------------------------------------------------
  // Starbase panel Client API.
  // ---------------------------------------------------------------------------

  static Map<String, String> _headers(String apiKey) => {
        'Authorization': 'Bearer $apiKey',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

  static Never _throwFor(http.Response response) {
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const BisectAuthException(
        'BisectHosting rejected the API key. Create one under '
        '$panelApiCredentialsHint and paste it exactly.',
      );
    }
    throw http.ClientException(
      'BisectHosting panel error ${response.statusCode}',
    );
  }

  /// Lists the servers the API key's account can access.
  static Future<List<BisectServer>> listServers(String apiKey) async {
    final response = await http
        .get(Uri.parse('$panelBaseUrl/api/client'), headers: _headers(apiKey))
        .timeout(_timeout);
    if (response.statusCode != 200) _throwFor(response);

    final decoded = jsonDecode(response.body);
    final data = decoded is Map ? decoded['data'] : null;
    if (data is! List) return const [];

    return data.whereType<Map>().map((item) {
      final attributes = item['attributes'];
      if (attributes is! Map) return null;
      return BisectServer(
        identifier: (attributes['identifier'] as String?) ?? '',
        name: (attributes['name'] as String?) ?? 'Server',
        description: (attributes['description'] as String?) ?? '',
        address: _defaultAllocationAddress(attributes),
      );
    }).whereType<BisectServer>().where((s) => s.identifier.isNotEmpty).toList();
  }

  static String? _defaultAllocationAddress(Map attributes) {
    final allocations =
        (attributes['relationships'] as Map?)?['allocations'] as Map?;
    final list = allocations?['data'];
    if (list is! List) return null;
    for (final allocation in list.whereType<Map>()) {
      final attrs = allocation['attributes'];
      if (attrs is! Map) continue;
      if (attrs['is_default'] == true) {
        final host = (attrs['ip_alias'] as String?) ?? (attrs['ip'] as String?);
        final port = attrs['port'];
        if (host != null && port != null) return '$host:$port';
      }
    }
    return null;
  }

  /// Current power state + resource usage of one server.
  static Future<BisectServerResources> fetchResources(
    String apiKey,
    String serverIdentifier,
  ) async {
    final response = await http
        .get(
          Uri.parse('$panelBaseUrl/api/client/servers/$serverIdentifier/resources'),
          headers: _headers(apiKey),
        )
        .timeout(_timeout);
    if (response.statusCode != 200) _throwFor(response);

    final decoded = jsonDecode(response.body);
    final attributes = decoded is Map ? decoded['attributes'] : null;
    final resources = attributes is Map ? attributes['resources'] : null;
    return BisectServerResources(
      state: attributes is Map
          ? (attributes['current_state'] as String?) ?? 'unknown'
          : 'unknown',
      cpuPercent: resources is Map
          ? (resources['cpu_absolute'] as num?)?.toDouble() ?? 0
          : 0,
      memoryBytes: resources is Map
          ? (resources['memory_bytes'] as num?)?.toInt() ?? 0
          : 0,
    );
  }

  /// Sends a power signal: 'start', 'restart', 'stop' or 'kill'.
  static Future<void> sendPowerSignal(
    String apiKey,
    String serverIdentifier,
    String signal,
  ) async {
    final response = await http
        .post(
          Uri.parse('$panelBaseUrl/api/client/servers/$serverIdentifier/power'),
          headers: _headers(apiKey),
          body: jsonEncode({'signal': signal}),
        )
        .timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwFor(response);
    }
  }
}
