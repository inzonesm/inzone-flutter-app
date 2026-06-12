import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/unity_game.dart';

/// Download state for a game in the hub.
enum GameDownloadState { notDownloaded, downloading, downloaded }

/// Manages fetching the game catalog from Firestore, downloading
/// game bundles from GCS, and tracking installed games on disk.
class GameHubService {
  GameHubService._();
  static final GameHubService instance = GameHubService._();

  static const _installedGamesKey = 'installed_unity_games';

  /// Base URL for the public-read GCS bucket where Unity Addressables
  /// artifacts (bundles + remote catalog) are stored. The platform segment
  /// must match the folder produced by the Unity Addressables build
  /// (ServerData/iOS or ServerData/Android) and the Remote.LoadPath set in
  /// the Unity Addressables profile.
  static final String bucketBase =
      'https://storage.googleapis.com/inzone-unity-bundles/'
      '${Platform.isAndroid ? 'Android' : 'iOS'}';

  final _gamesRef = FirebaseFirestore.instance.collection('unityGames');
  final _dio = Dio();

  /// Installed game IDs mapped to their installed version + bundle file.
  /// Format: { gameId: "version|bundleFile" }
  final Map<String, _InstalledEntry> _installedGames = {};

  /// IDs currently being downloaded.
  final Set<String> _downloading = {};

  /// Active cancel tokens for in-progress downloads.
  final Map<String, CancelToken> _cancelTokens = {};

  /// Lazily resolved path to the bundle storage directory.
  String? _bundleDir;

  Future<String> get bundleDir async {
    if (_bundleDir != null) return _bundleDir!;
    final appSupport = await getApplicationSupportDirectory();
    final dir = Directory('${appSupport.path}/unity_bundles');
    if (!await dir.exists()) await dir.create(recursive: true);
    _bundleDir = dir.path;
    return _bundleDir!;
  }

  // ------------------------------------------------------------------
  // Catalog
  // ------------------------------------------------------------------

  /// Fetch all active games once; callers derive categories and filter
  /// client-side so the collection is only read a single time per refresh.
  Future<List<UnityGame>> fetchGames() async {
    final snapshot = await _gamesRef.get();
    return snapshot.docs
        .map((doc) => UnityGame.fromFirestore(doc))
        .where((g) => g.isActive)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  // ------------------------------------------------------------------
  // Download state
  // ------------------------------------------------------------------

  Future<void> loadInstalledGames() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_installedGamesKey) ?? [];
    _installedGames.clear();
    for (final entry in list) {
      final parsed = _InstalledEntry.decode(entry);
      if (parsed != null) _installedGames[parsed.gameId] = parsed;
    }
    // Verify files still exist on disk
    await _pruneOrphans();
  }

  Future<void> _saveInstalledGames() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _installedGames.values.map((e) => e.encode()).toList();
    await prefs.setStringList(_installedGamesKey, list);
  }

  /// Remove entries whose bundle file no longer exists on disk.
  Future<void> _pruneOrphans() async {
    final dir = await bundleDir;
    final toRemove = <String>[];
    for (final entry in _installedGames.entries) {
      final file = File('$dir/${entry.value.bundleFile}');
      if (!await file.exists()) {
        toRemove.add(entry.key);
      }
    }
    if (toRemove.isNotEmpty) {
      for (final id in toRemove) {
        _installedGames.remove(id);
      }
      await _saveInstalledGames();
    }
  }

  GameDownloadState getDownloadState(UnityGame game) {
    if (_downloading.contains(game.id)) return GameDownloadState.downloading;
    if (_installedGames.containsKey(game.id)) {
      return GameDownloadState.downloaded;
    }
    return GameDownloadState.notDownloaded;
  }

  bool hasUpdate(UnityGame game) {
    final installed = _installedGames[game.id];
    return installed != null && installed.version != game.version;
  }

  /// Path to the locally-downloaded bundle for [game], or null if not installed.
  Future<String?> getLocalBundlePath(UnityGame game) async {
    final installed = _installedGames[game.id];
    if (installed == null) return null;
    final dir = await bundleDir;
    final path = '$dir/${installed.bundleFile}';
    if (await File(path).exists()) return path;
    return null;
  }

  /// Total disk space used by downloaded bundles, in bytes.
  Future<int> getInstalledSizeBytes() async {
    final dir = await bundleDir;
    int total = 0;
    for (final entry in _installedGames.values) {
      final file = File('$dir/${entry.bundleFile}');
      if (await file.exists()) total += await file.length();
    }
    return total;
  }

  // ------------------------------------------------------------------
  // Download
  // ------------------------------------------------------------------

  /// Download the game's asset bundle from GCS to local storage.
  ///
  /// Reports progress via [onProgress] (0.0 → 1.0).
  /// Throws on network errors; the caller should handle them.
  ///
  /// Unity picks the downloaded file up at load time: the bundle directory is
  /// passed to AddressableSceneLoader, which redirects any catalog entry whose
  /// filename exists locally instead of re-downloading it from GCS.
  Future<void> downloadGame(
    UnityGame game, {
    void Function(double progress)? onProgress,
  }) async {
    if (game.bundleFile.isEmpty) {
      throw StateError(
        'Game "${game.title}" has no bundleFile set in Firestore.',
      );
    }

    _downloading.add(game.id);
    final cancelToken = CancelToken();
    _cancelTokens[game.id] = cancelToken;

    try {
      final dir = await bundleDir;
      final savePath = '$dir/${game.bundleFile}';
      final url = '$bucketBase/${game.bundleFile}';

      debugPrint('[GameHub] Downloading $url → $savePath');

      await _dio.download(
        url,
        savePath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            onProgress?.call(received / total);
          }
        },
      );

      // Mark as installed
      _installedGames[game.id] = _InstalledEntry(
        gameId: game.id,
        version: game.version,
        bundleFile: game.bundleFile,
      );
      await _saveInstalledGames();
      debugPrint('[GameHub] Download complete: ${game.bundleFile}');
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        debugPrint('[GameHub] Download cancelled: ${game.title}');
        // Clean up partial file
        final dir = await bundleDir;
        final partial = File('$dir/${game.bundleFile}');
        if (await partial.exists()) await partial.delete();
      } else {
        rethrow;
      }
    } finally {
      _downloading.remove(game.id);
      _cancelTokens.remove(game.id);
    }
  }

  /// Cancel an in-progress download.
  void cancelDownload(String gameId) {
    _cancelTokens[gameId]?.cancel();
  }

  /// Remove a game's local bundle file and clear its installed state.
  Future<void> removeGame(String gameId) async {
    cancelDownload(gameId);
    final installed = _installedGames[gameId];
    if (installed != null) {
      final dir = await bundleDir;
      final file = File('$dir/${installed.bundleFile}');
      if (await file.exists()) await file.delete();
    }
    _installedGames.remove(gameId);
    _downloading.remove(gameId);
    await _saveInstalledGames();
  }
}

/// Persisted metadata for a single installed game.
class _InstalledEntry {
  final String gameId;
  final String version;
  final String bundleFile;

  _InstalledEntry({
    required this.gameId,
    required this.version,
    required this.bundleFile,
  });

  /// Encode as "gameId|version|bundleFile" for SharedPreferences storage.
  String encode() => '$gameId|$version|$bundleFile';

  /// Decode from "gameId|version|bundleFile". Returns null if malformed.
  static _InstalledEntry? decode(String raw) {
    final parts = raw.split('|');
    if (parts.length == 3) {
      return _InstalledEntry(
        gameId: parts[0],
        version: parts[1],
        bundleFile: parts[2],
      );
    }
    // Legacy format: "gameId:version" — treat as no bundle file
    final legacy = raw.split(':');
    if (legacy.length == 2) {
      return _InstalledEntry(
        gameId: legacy[0],
        version: legacy[1],
        bundleFile: '',
      );
    }
    return null;
  }
}
