import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// media_kit's PlayerState is hidden: this file only ever accesses it via
// `player.state` (never by type name), while youtube_player_flutter's
// PlayerState IS referenced by name — hiding resolves the ambiguity.
import 'package:media_kit/media_kit.dart' hide PlayerState;
import 'package:media_kit_video/media_kit_video.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart' as vp;
import 'package:visibility_detector/visibility_detector.dart';
import 'package:inzone/services/appsflyer_service.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

// Global mute state manager
class VideoMuteManager {
  static bool _isMuted = true;
  static final StreamController<bool> _muteStateController =
      StreamController<bool>.broadcast();

  static Stream<bool> get muteStateStream => _muteStateController.stream;

  static bool get isMuted => _isMuted;

  static void setMuted(bool muted) {
    if (_isMuted != muted) {
      _isMuted = muted;
      _muteStateController.add(_isMuted);
    }
  }

  static void toggleMute() {
    setMuted(!_isMuted);
  }

  static void dispose() {
    _muteStateController.close();
  }
}

// Notification to communicate video aspect ratio to parent widgets
class VideoAspectRatioNotification extends Notification {
  final double aspectRatio;

  VideoAspectRatioNotification(this.aspectRatio);
}

// Track all active players (and their VideoControllers) for pausing others
// when a new video plays and for safe bulk disposal.
final Map<String, ({Player player, VideoController? controller})>
    _activePlayers = {};

// Track currently playing video
String? _currentlyPlayingVideoUrl;

// Last known playback position per video URL, kept fresh by the players'
// existing tracking callbacks. Lets a newly created player (e.g. the
// fullscreen viewer) resume where inline playback was instead of restarting.
final Map<String, Duration> _videoPositionRegistry = {};

/// Safely disposes a MediaKit Player on iOS without crashing.
///
/// The crash occurs because mpv's native `core_thread` calls
/// `mp_shutdown_clients` → `send_event` → `append_event` during disposal,
/// which invokes FFI callbacks registered by the [VideoController].
/// If the [VideoController] has been garbage-collected before `dispose()`
/// completes, the Dart VM hits a `DLRT_GetFfiCallbackMetadata` assertion
/// failure and crashes.
///
/// To prevent this we:
/// 1. Keep a strong reference to the [VideoController] until disposal is done.
/// 2. Pause & stop the player to minimize in-flight events.
/// 3. Wait for mpv's threads to quiesce.
/// 4. Only then call `dispose()`, and release the controller reference after.
Future<void> _safeDisposeMediaKitPlayer(
  Player player, [
  VideoController? videoController,
]) async {
  try {
    // Halt playback to stop new events from being generated.
    try {
      await player.pause();
    } catch (_) {}
    try {
      await player.stop();
    } catch (_) {}

    // Give mpv's native threads time to finish processing queued events.
    await Future.delayed(const Duration(milliseconds: 300));

    // Dispose the player. This triggers mp_shutdown_clients on the native
    // core_thread. The VideoController (and its FFI callbacks) MUST still
    // be alive at this point — holding `videoController` in this scope
    // prevents the GC from collecting it.
    await player.dispose();

    // Keep the VideoController reference alive a bit longer so the GC
    // doesn't collect it while mpv's pthread is still unwinding.
    await Future.delayed(const Duration(milliseconds: 200));
  } catch (e) {
    debugPrint('Error in _safeDisposeMediaKitPlayer: $e');
  }
  // `videoController` goes out of scope here → safe for GC now.
}

void disposeAllVideoCache() {
  try {
    for (final entry in _activePlayers.entries) {
      final player = entry.value.player;
      final controller = entry.value.controller;
      // Fire-and-forget: dispose each player safely in a microtask.
      // CRITICAL: pass the VideoController so it stays alive during
      // mpv's mp_shutdown_clients → FFI callback chain.
      Future.microtask(() => _safeDisposeMediaKitPlayer(player, controller));
    }
    _activePlayers.clear();
    _currentlyPlayingVideoUrl = null;
    debugPrint('All video players disposal initiated');
  } catch (e) {
    debugPrint('Error disposing all video players: $e');
  }
}

// Pause all videos except the specified URL
void _pauseOtherVideos(String currentVideoUrl) {
  if (_currentlyPlayingVideoUrl == currentVideoUrl) return;

  // Pause the previously playing video
  if (_currentlyPlayingVideoUrl != null) {
    final previousEntry = _activePlayers[_currentlyPlayingVideoUrl];
    if (previousEntry != null && previousEntry.player.state.playing) {
      previousEntry.player.pause();
      debugPrint('Paused previous video: $_currentlyPlayingVideoUrl');
    }
  }

  _currentlyPlayingVideoUrl = currentVideoUrl;
}

/// Video widget with autoplay functionality.
/// Videos automatically start playing when they become visible (>50% on screen)
/// and pause when they go out of view. Supports caching, tracking, and manual controls.
class VideoWidget extends StatefulWidget {
  final String videoUrl;
  final Function(double)? onAspectRatioUpdated;
  final String? postId; // Add postId for tracking
  final String? category; // Add category for tracking
  final String? authorId; // Add authorId for tracking

  /// True when this widget is hosted by the fullscreen viewer. Used to keep
  /// media_kit's built-in gesture controls fullscreen-only so they can't
  /// hijack the feed's vertical scroll during inline playback.
  final bool isFullscreen;

  const VideoWidget({
    super.key,
    required this.videoUrl,
    this.onAspectRatioUpdated,
    this.postId,
    this.category,
    this.authorId,
    this.isFullscreen = false,
  });

  @override
  _VideoWidgetState createState() => _VideoWidgetState();
}

class _VideoWidgetState extends State<VideoWidget> with WidgetsBindingObserver {
  // Use standard video_player on Android for better compatibility
  static final bool _useAndroidVideoPlayer = Platform.isAndroid;

  // Android video_player controller
  vp.VideoPlayerController? _androidController;

  Player? _mediaKitPlayer;
  VideoController? _mediaKitVideoController;
  bool _isInitialized = false;
  bool _isPlayable = true;
  bool _isLoading = true;
  Timer? _loadingTimeoutTimer;
  String _errorMessage = 'Unsupported video format.';
  final String _uniqueViewId = UniqueKey().toString();
  bool _isVisible = false;

  bool _isYouTube = false;
  bool _isShorts = false;
  YoutubePlayerController? _ytController;
  VoidCallback? _ytListener;

  // The extracted YouTube video ID (used for the thumbnail cover below).
  String? _ytVideoId;

  // Set once the player has actually rendered frames. Used so the cover
  // only treats buffering as "keep video visible" after playback started.
  bool _ytHasStartedPlaying = false;

  // Set when the video became visible before the YouTube iframe was ready;
  // consumed by _ytListener to start playback as soon as it is. Needed now
  // that inline videos initialize offscreen (preload) with autoPlay off.
  bool _ytWantsPlay = false;

  // Cache of YouTube video orientation (videoId -> true if vertical), filled
  // by the /shorts/ URL check, the oEmbed probe, and duration detection.
  // Persisted across sessions so revisited videos size correctly BEFORE the
  // iframe loads — this is what prevents the 16:9 -> 9:16 layout jump on
  // Shorts the user has seen before.
  static final Map<String, bool> _ytVerticalCache = {};
  static Future<void>? _ytVerticalCacheFuture;
  static Timer? _ytVerticalCacheSaveTimer;
  static const String _ytVerticalCacheKey = 'yt_vertical_cache_v1';

  static Future<void> _loadYtVerticalCache() {
    return _ytVerticalCacheFuture ??= () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(_ytVerticalCacheKey);
        if (raw == null || raw.isEmpty) return;
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          decoded.forEach((id, v) {
            if (v is bool) _ytVerticalCache.putIfAbsent(id, () => v);
          });
        }
      } catch (_) {
        // Best-effort cache; sizing falls back to runtime detection.
      }
    }();
  }

  static void _saveYtVerticalCache() {
    // Debounced so bursts of updates write once.
    _ytVerticalCacheSaveTimer?.cancel();
    _ytVerticalCacheSaveTimer = Timer(const Duration(seconds: 2), () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
            _ytVerticalCacheKey, jsonEncode(_ytVerticalCache));
      } catch (_) {}
    });
  }

  // Add scrubbing state variables
  bool _isScrubbing = false;
  Duration _scrubbingPosition = Duration.zero;
  Timer? _scrubbingTimer;

  // Control visibility of play/pause button
  bool _showPlayPauseButton = true;
  Timer? _hideControlsTimer;

  // Track fullscreen state
  bool _isFullscreen = false;

  // Subscription to mute state changes
  StreamSubscription? _muteSubscription;
  StreamSubscription? _positionSubscription;

  // Video tracking variables
  bool _hasTrackedCompletion = false;
  final Set<int> _trackedProgressMilestones =
      {}; // Track 25%, 50%, 75% milestones
  DateTime? _videoStartTime;
  Duration _totalWatchTime = Duration.zero;
  Duration _lastPosition = Duration.zero;
  Timer? _trackingTimer;
  bool _dimensionsSet = false;

  @override
  void initState() {
    super.initState();

    // Register this object as an observer for app lifecycle changes
    WidgetsBinding.instance.addObserver(this);

    // Defer initialization to avoid blocking the UI
    // Always create fresh player instances to avoid corruption from reusing cached controllers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializeVideo();
      }
    });

    _loadingTimeoutTimer = Timer(const Duration(seconds: 15), () {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
          _isPlayable = false;
          _errorMessage =
              'Video loading timed out. Please check your connection and try again.';
        });
      }
    });

    // Subscribe to global mute state changes
    _muteSubscription = VideoMuteManager.muteStateStream.listen((isMuted) {
      // Handle Android video player
      if (_useAndroidVideoPlayer && _androidController != null && mounted) {
        _androidController!.setVolume(isMuted ? 0 : 1.0);
        setState(() {}); // Trigger rebuild to update UI
      }
      // Handle MediaKit player
      else if (_mediaKitPlayer != null && mounted) {
        _mediaKitPlayer!.setVolume(isMuted ? 0 : 100);
        setState(() {}); // Trigger rebuild to update UI
      }

      if (_ytController != null && mounted) {
        try {
          if (isMuted) {
            _ytController!.mute();
          } else {
            _ytController!.unMute();
          }
        } catch (_) {}
        // Ensure the mute icon updates for YouTube path as well
        if (mounted) setState(() {});
      }
    });

    // Apply current global mute state
    if (_useAndroidVideoPlayer && _androidController != null) {
      _androidController!.setVolume(VideoMuteManager.isMuted ? 0 : 1.0);
    } else if (_mediaKitPlayer != null) {
      _mediaKitPlayer!.setVolume(VideoMuteManager.isMuted ? 0 : 100);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Handle app lifecycle changes
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // App is going to background or is inactive
      if (_isFullscreen) {
        // Exit fullscreen mode
        _isFullscreen = false;
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
        ]);
        SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.edgeToEdge,
        );
      }

      // Pause video when app goes to background
      if (_useAndroidVideoPlayer &&
          _androidController != null &&
          _androidController!.value.isPlaying) {
        _androidController!.pause();
      } else if (_mediaKitPlayer != null && _mediaKitPlayer!.state.playing) {
        _mediaKitPlayer!.pause();
      }
      if (_isYouTube) {
        try {
          _ytController?.pause();
        } catch (_) {}
      }
    }
  }

  Future<void> _initializeVideo() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _isPlayable = true;
    });

    // Add a small delay to allow the UI to render first
    await Future.delayed(const Duration(milliseconds: 50));

    // Process the URL to handle YouTube links
    String mediaUrl = widget.videoUrl;

    // Check if it's a YouTube URL and initialize YouTube player path
    if (_isYoutubeUrl(widget.videoUrl)) {
      final videoId = _getYoutubeVideoId(widget.videoUrl);
      if (videoId != null) {
        _isYouTube = true;
        // Ensure the persisted orientation cache is loaded before consulting
        // it (no-op after the first video of the session).
        await _loadYtVerticalCache();
        // YouTube-only sizing: 9:16 when the URL self-identifies as a Short,
        // when the session cache says so, or (async, background) when the
        // oEmbed title carries a '#shorts' hashtag — which covers the feed's
        // auto-shared posts. Otherwise the duration-based check in
        // _ytListener adjusts the size once metadata loads, as originally.
        _ytVideoId = videoId;
        _ytHasStartedPlaying = false;
        if (widget.videoUrl.contains('/shorts/') ||
            _ytVerticalCache[videoId] == true) {
          _isShorts = true;
          if (_ytVerticalCache[videoId] != true) {
            _ytVerticalCache[videoId] = true;
            _saveYtVerticalCache();
          }
        } else if (!_ytVerticalCache.containsKey(videoId)) {
          _probeYoutubeShortsHashtag(videoId);
        }
        try {
          _ytController?.dispose();
        } catch (_) {}
        _ytController = YoutubePlayerController(
          initialVideoId: videoId,
          flags: YoutubePlayerFlags(
            // Inline videos now initialize while still offscreen (preload),
            // so they must not autoplay - the VisibilityDetector (or the
            // wants-play handoff in _ytListener) starts playback when the
            // video actually scrolls into view.
            autoPlay: widget.isFullscreen,
            mute: VideoMuteManager.isMuted,
            disableDragSeek: false,
            // Resume where playback last was (fullscreen viewer, or an
            // inline player rebuilt after being released offscreen).
            startAt: _videoPositionRegistry[widget.videoUrl]?.inSeconds ?? 0,
            // Loop so the video never reaches the "ended" state — YouTube's
            // end screen (replay button, share, YouTube logo) is drawn by the
            // iframe itself and would appear over the video otherwise.
            loop: true,
            isLive: false,
            forceHD: false,
            enableCaption: false,
            useHybridComposition: true,
          ),
        );

        _ytListener = () {
          try {
            final value = _ytController!.value;
            // Deferred autoplay: the video became visible before the iframe
            // was ready. Start playback now that it is (consumed once, so a
            // user pause is never overridden).
            if (_ytWantsPlay && value.isReady) {
              _ytWantsPlay = false;
              _pauseOtherVideos(widget.videoUrl);
              _ytController!.play();
            }
            // Track when frames have actually started rendering — the
            // thumbnail cover in build() uses this to stay up during the
            // initial load (hiding the iframe's spinner/title UI) without
            // flashing during mid-playback buffering.
            if (!_ytHasStartedPlaying &&
                value.playerState == PlayerState.playing) {
              _ytHasStartedPlaying = true;
            }
            // Keep the shared position registry fresh so a fullscreen viewer
            // opened from this video resumes at the right spot.
            if (value.position > Duration.zero) {
              _videoPositionRegistry[widget.videoUrl] = value.position;
            }
            final d = value.metaData.duration;
            if (d.inSeconds > 0) {
              final detectedShorts = d.inSeconds <= 65;
              // Cache the confirmed orientation so any NEW player instance for
              // this video (e.g. the fullscreen viewer) is sized correctly on
              // its very first frame instead of flashing 16:9 first.
              if (_ytVerticalCache[videoId] != detectedShorts) {
                _ytVerticalCache[videoId] = detectedShorts;
                _saveYtVerticalCache();
              }
              if (detectedShorts != _isShorts) {
                if (mounted) {
                  setState(() {
                    _isShorts = detectedShorts;
                  });
                }
                if (widget.onAspectRatioUpdated != null) {
                  widget.onAspectRatioUpdated!(_isShorts ? (9 / 16) : (16 / 9));
                }
              }
            }
          } catch (_) {}
        };
        _ytController!.addListener(_ytListener!);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && widget.onAspectRatioUpdated != null) {
            widget.onAspectRatioUpdated!(_isShorts ? (9 / 16) : (16 / 9));
          }
        });

        if (mounted) {
          setState(() {
            _isInitialized = true;
            _isLoading = false;
          });
        }
        return;
      } else {
        setState(() {
          _isPlayable = false;
          _isLoading = false;
          _errorMessage = 'Invalid YouTube URL';
        });
        return;
      }
    }

    // Initialize video player - use standard video_player on Android for better compatibility
    if (_useAndroidVideoPlayer) {
      await _initializeAndroidVideoPlayer(mediaUrl);
    } else {
      await _initializeMediaKitPlayer(mediaUrl);
    }
  }

  Future<void> _initializeAndroidVideoPlayer(String videoPath) async {
    debugPrint('Starting Android VideoPlayer initialization: $videoPath');

    try {
      // Dispose any existing controller
      if (_androidController != null) {
        await _androidController!.dispose();
        _androidController = null;
      }

      // Create the video player controller
      _androidController =
          vp.VideoPlayerController.networkUrl(Uri.parse(videoPath));

      // Set volume based on global mute state
      await _androidController!.setVolume(VideoMuteManager.isMuted ? 0 : 1.0);

      // Initialize the controller
      await _androidController!.initialize();

      // Resume from the last known position: covers the fullscreen viewer
      // AND inline players rebuilt after the feed released them offscreen.
      final resumeAt = _videoPositionRegistry[widget.videoUrl];
      if (resumeAt != null && resumeAt > Duration.zero) {
        await _androidController!.seekTo(resumeAt);
      }

      // Set up listener for aspect ratio
      if (_androidController!.value.isInitialized) {
        final aspectRatio = _androidController!.value.aspectRatio;
        if (widget.onAspectRatioUpdated != null) {
          widget.onAspectRatioUpdated!(aspectRatio);
        }
      }

      // Set up position tracking timer
      _trackingTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
        if (mounted &&
            _androidController != null &&
            _androidController!.value.isInitialized) {
          final position = _androidController!.value.position;
          // Shared registry: lets the fullscreen viewer resume from here.
          _videoPositionRegistry[widget.videoUrl] = position;
          _updateWatchTime(position);
          _trackVideoProgress(position);
        }
      });

      debugPrint('Android VideoPlayer opened successfully');

      // Auto-play when visible
      if (_isVisible) {
        await _androidController!.play();
      }

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error initializing Android VideoPlayer: $e');
      if (mounted) {
        setState(() {
          _isPlayable = false;
          _isLoading = false;
          _errorMessage =
              'Video loading error: ${e.toString().substring(0, math.min(100, e.toString().length))}';
        });
      }
    }
  }

  bool _isYoutubeUrl(String url) {
    // Check if the URL contains youtube.com or youtu.be
    return url.contains('youtube.com') || url.contains('youtu.be');
  }

  /// Background best-effort check of the video's oEmbed TITLE for a
  /// creator-added Shorts hashtag ('#shorts', '#short', '#ytshorts', ...) —
  /// the feed's auto-shared posts hit this path. Only a POSITIVE match does
  /// anything: it marks the video as a Short and updates the layout. On no
  /// match or any failure this is a no-op and the duration-based detection
  /// behaves exactly as before.
  ///
  /// NOTE: oEmbed's width/height fields are deliberately NOT used — YouTube
  /// reports a 16:9 embed (e.g. 200x113) even for vertical Shorts.
  Future<void> _probeYoutubeShortsHashtag(String videoId) async {
    try {
      final response = await http
          .get(Uri.parse(
              'https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=$videoId&format=json'))
          .timeout(const Duration(seconds: 3));
      if (response.statusCode != 200) return;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return;
      final title = (decoded['title'] as String? ?? '').toLowerCase();
      // '#short' also matches '#shorts'; '#ytshort' also matches '#ytshorts'.
      final bool tagged =
          title.contains('#short') || title.contains('#ytshort');
      if (!tagged) return;

      _ytVerticalCache[videoId] = true;
      _saveYtVerticalCache();

      if (!mounted || !_isYouTube) return;
      if (!_isShorts) {
        setState(() {
          _isShorts = true;
        });
        if (widget.onAspectRatioUpdated != null) {
          widget.onAspectRatioUpdated!(9 / 16);
        }
      }
    } catch (_) {
      // Probe is best-effort only; sizing falls back to duration detection.
    }
  }

  String? _getYoutubeVideoId(String url) {
    // Extract YouTube video ID from various URL formats
    RegExp regExp = RegExp(
      r'(?:youtube\.com\/(?:[^\/\n\s]+\/\S+\/|(?:v|e(?:mbed)?)\/|shorts\/|\S*?[?&]v=)|youtu\.be\/)([a-zA-Z0-9_-]{11})',
      caseSensitive: false,
    );

    Match? match = regExp.firstMatch(url);
    return match?.group(1);
  }

  Future<void> _initializeMediaKitPlayer(String videoPath) async {
    debugPrint('Starting MediaKit Player initialization: $videoPath');

    try {
      // Dispose any existing MediaKit player before creating a new one.
      // CRITICAL: pass the VideoController so it stays alive during native
      // mpv shutdown — prevents DLRT_GetFfiCallbackMetadata crash on iOS.
      if (_mediaKitPlayer != null) {
        final oldPlayer = _mediaKitPlayer!;
        final oldController = _mediaKitVideoController;
        _mediaKitPlayer = null;
        _mediaKitVideoController = null;
        await _safeDisposeMediaKitPlayer(oldPlayer, oldController);
      }

      // Initialize the player with configuration for showing controls
      _mediaKitPlayer = Player();

      // Set volume immediately before opening media
      await _mediaKitPlayer!.setVolume(VideoMuteManager.isMuted ? 0 : 100);

      // Create video controller with the proper configuration for the platform
      // Use AndroidVideoControllerConfiguration for better Android/emulator compatibility
      _mediaKitVideoController = VideoController(
        _mediaKitPlayer!,
        configuration: VideoControllerConfiguration(
          // Enable software rendering on Android for better emulator compatibility
          enableHardwareAcceleration: !Platform.isAndroid,
        ),
      );

      // Create a completer for tracking MediaKit initialization
      final Completer<void> mediaKitCompleter = Completer<void>();

      // Setup listener for MediaKit player state changes
      final durationStream = _mediaKitPlayer!.stream.duration;
      final subscription = durationStream.listen((duration) {
        if (duration > Duration.zero && !mediaKitCompleter.isCompleted) {
          mediaKitCompleter.complete();
        }
      });

      // Optimized: Use a periodic timer instead of listening to every frame
      // Check position every 500ms instead of 60+ times per second
      _trackingTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
        if (mounted && _mediaKitPlayer != null) {
          final position = _mediaKitPlayer!.state.position;

          // Shared registry: lets the fullscreen viewer resume from here.
          _videoPositionRegistry[widget.videoUrl] = position;

          // Update watch time tracking
          _updateWatchTime(position);

          // Track video progress and completion
          _trackVideoProgress(position);
        }
      });

      // Set dimensions once when available
      _positionSubscription =
          _mediaKitPlayer!.stream.position.listen((position) {
        if (mounted && !_dimensionsSet) {
          final videoWidth = _mediaKitPlayer!.state.width?.toDouble();
          final videoHeight = _mediaKitPlayer!.state.height?.toDouble();

          if (videoWidth != null &&
              videoHeight != null &&
              videoWidth > 0 &&
              videoHeight > 0) {
            _dimensionsSet = true;
            final aspectRatio = videoWidth / videoHeight;
            if (widget.onAspectRatioUpdated != null) {
              widget.onAspectRatioUpdated!(aspectRatio);
            }

            // Cancel subscription after dimensions are set
            _positionSubscription?.cancel();
          }
        }
      });

      // Error handler for MediaKit
      _mediaKitPlayer!.stream.error.listen((error) {
        if (!mediaKitCompleter.isCompleted) {
          mediaKitCompleter.completeError(error);
        }
      });

      // Start opening the media
      unawaited(_mediaKitPlayer!.open(Media(videoPath), play: false));

      // Wait for either playback to start or timeout
      await mediaKitCompleter.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException(
              'MediaKit initialization timed out after 10 seconds');
        },
      );

      // Cancel subscription after we're done
      subscription.cancel();

      // Configure playback rate (volume is already set)
      await _mediaKitPlayer!.setRate(1.0);

      // Resume from the last known position: covers the fullscreen viewer
      // AND inline players rebuilt after the feed released them offscreen.
      final resumeAt = _videoPositionRegistry[widget.videoUrl];
      if (resumeAt != null && resumeAt > Duration.zero) {
        await _mediaKitPlayer!.seek(resumeAt);
      }

      debugPrint('MediaKit Player opened successfully');

      // Register this player in active players map for pausing other videos
      _activePlayers[widget.videoUrl] = (
        player: _mediaKitPlayer!,
        controller: _mediaKitVideoController,
      );

      // Autoplay only when actually visible. Videos now initialize while
      // still below the viewport (preload) - they must not steal the
      // "currently playing" slot or start decoding audio offscreen; the
      // VisibilityDetector starts playback when the video scrolls in.
      if (_isVisible || widget.isFullscreen) {
        _pauseOtherVideos(widget.videoUrl);
        _mediaKitPlayer!.play();
      }

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error initializing MediaKit Player: $e');
      if (mounted) {
        setState(() {
          _isPlayable = false;
          _isLoading = false;
          _errorMessage =
              'Video loading error: ${e.toString().substring(0, math.min(100, e.toString().length))}';
        });
      }
    }
  }

  Widget _buildAndroidVideoPlayer(BuildContext context) {
    // Show loading state
    if (_isLoading) {
      return Container(
        color: Colors.black,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    // Show error state
    if (!_isPlayable || !_isInitialized || _androidController == null) {
      return Container(
        color: Colors.grey[300],
        child: Center(
          child: Text(
            _errorMessage,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final aspectRatio = _androidController!.value.aspectRatio;
    final isPlaying = _androidController!.value.isPlaying;

    final double safeAspectRatio = aspectRatio > 0 ? aspectRatio : 9 / 16;

    final Widget videoContent = Stack(
        children: [
          // The video player
          vp.VideoPlayer(_androidController!),

          // Custom overlay for capturing tap to pause/play
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                if (_androidController != null) {
                  setState(() {
                    _showPlayPauseButton = true;
                  });

                  if (_androidController!.value.isPlaying) {
                    _androidController!.pause();
                    _trackVideoPause();
                  } else {
                    _androidController!.play();
                    _trackVideoStart();
                    // Ensure volume is set when manually playing
                    if (!VideoMuteManager.isMuted) {
                      _androidController!.setVolume(1.0);
                    }
                    _startHideControlsTimer();
                  }
                }
              },
              child: Container(color: Colors.transparent),
            ),
          ),

          // Play/Pause button in the center
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: !isPlaying ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    if (_androidController != null) {
                      if (_androidController!.value.isPlaying) {
                        _androidController!.pause();
                        _trackVideoPause();
                      } else {
                        _androidController!.play();
                        _trackVideoStart();
                        if (!VideoMuteManager.isMuted) {
                          _androidController!.setVolume(1.0);
                        }
                      }
                      setState(() {});
                    }
                  },
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Mute button overlay
          Positioned(
            bottom: 60,
            right: 8,
            child: GestureDetector(
              onTap: () {
                VideoMuteManager.toggleMute();
              },
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(
                  VideoMuteManager.isMuted ? Icons.volume_off : Icons.volume_up,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),

          // Progress bar at the bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: vp.VideoProgressIndicator(
              _androidController!,
              allowScrubbing: true,
              colors: vp.VideoProgressColors(
                playedColor: Colors.white,
                bufferedColor: Colors.white.withOpacity(0.5),
                backgroundColor: Colors.grey.withOpacity(0.3),
              ),
            ),
          ),
        ],
    );

    final Widget videoWidget = AspectRatio(
      aspectRatio: safeAspectRatio,
      child: videoContent,
    );

    return VisibilityDetector(
      key: Key('video-android-${widget.videoUrl}'),
      onVisibilityChanged: (visibilityInfo) {
        final isVisible = visibilityInfo.visibleFraction > 0.5;
        if (_isVisible != isVisible) {
          _isVisible = isVisible;
          if (_androidController != null &&
              _androidController!.value.isInitialized) {
            if (isVisible) {
              _androidController!.play();
            } else {
              _androidController!.pause();
            }
          }
        }
      },
      child: videoWidget,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isYouTube) {
      if (_isLoading) {
        return Container(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height,
          color: Colors.black,
          child: const Center(child: CircularProgressIndicator()),
        );
      }

      if (!_isInitialized || _ytController == null) {
        return Container(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height,
          color: Colors.grey[300],
          child: Center(
            child: Text(
              _errorMessage,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ),
        );
      }

      final double ytAspect = _isShorts ? (9 / 16) : (16 / 9);
      final Widget ytCore = YoutubePlayer(
        controller: _ytController!,
        // Disabled: the custom seekable progress bar below replaces it.
        showVideoProgressIndicator: false,
      );

      final Widget ytContent = Stack(
          children: [
            // SCROLL FIX: the player is wrapped in IgnorePointer so touches
            // never reach the YouTube WebView — drags scroll the feed instead
            // of being swallowed, and the WebView can never show its native
            // UI (pause overlay with title/share/YouTube logo) from user
            // interaction. Playback is controlled by the custom overlays
            // below (same UX as the media_kit/Android players).
            Positioned.fill(
              child: IgnorePointer(child: ytCore),
            ),

            // Thumbnail cover: the YouTube iframe draws its own UI (title
            // bar, share button, YouTube logo, spinner) while loading,
            // paused, or ended — and it can't be disabled. This cover hides
            // the iframe whenever it isn't actively rendering video frames.
            // Mid-playback buffering keeps the video visible.
            ValueListenableBuilder<YoutubePlayerValue>(
              valueListenable: _ytController!,
              builder: (context, value, _) {
                final bool coverVisible = !(value.isPlaying ||
                    (_ytHasStartedPlaying &&
                        value.playerState == PlayerState.buffering));
                return Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: coverVisible ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        color: Colors.black,
                        child: _ytVideoId != null
                            ? Image.network(
                                'https://i.ytimg.com/vi/$_ytVideoId/hqdefault.jpg',
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const SizedBox.expand(),
                              )
                            : null,
                      ),
                    ),
                  ),
                );
              },
            ),

            // Custom overlay for capturing tap to pause/play. Only a tap
            // recognizer is registered, so vertical drags still scroll the
            // feed — the scroll fix is preserved.
            Positioned.fill(
              child: GestureDetector(
                onTap: _toggleYoutubePlayPause,
                child: Container(color: Colors.transparent),
              ),
            ),

            // Play/Pause button in the center (visible while paused)
            ValueListenableBuilder<YoutubePlayerValue>(
              valueListenable: _ytController!,
              builder: (context, value, _) {
                final bool isPlaying = value.isPlaying;
                return Positioned.fill(
                  child: AnimatedOpacity(
                    opacity: !isPlaying ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Center(
                      child: GestureDetector(
                        onTap: _toggleYoutubePlayPause,
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            // Mute button overlay
            Positioned(
              bottom: 60,
              right: 8,
              child: GestureDetector(
                onTap: () {
                  VideoMuteManager.toggleMute();
                },
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Icon(
                    VideoMuteManager.isMuted
                        ? Icons.volume_off
                        : Icons.volume_up,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),

            // Timestamp overlay during scrubbing
            if (_isScrubbing)
              Positioned(
                bottom: 30,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _formatDuration(_scrubbingPosition),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),

            // Custom seekable progress bar — same style as the media_kit
            // player, driven by the YouTube controller.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ValueListenableBuilder<YoutubePlayerValue>(
                valueListenable: _ytController!,
                builder: (context, value, _) {
                  final Duration duration = value.metaData.duration;
                  if (duration.inMilliseconds <= 0) return const SizedBox();

                  final Duration position =
                      _isScrubbing ? _scrubbingPosition : value.position;

                  double progress =
                      position.inMilliseconds / duration.inMilliseconds;
                  progress = progress.clamp(0.0, 1.0);

                  return GestureDetector(
                    onTapDown: (details) {
                      _handleYtProgressBarInteraction(
                          details.localPosition.dx, context, duration,
                          isStart: true);
                    },
                    onTapUp: (details) {
                      _handleYtProgressBarInteraction(
                          details.localPosition.dx, context, duration,
                          isEnd: true);
                    },
                    onHorizontalDragStart: (details) {
                      _handleYtProgressBarInteraction(
                          details.localPosition.dx, context, duration,
                          isStart: true);
                    },
                    onHorizontalDragUpdate: (details) {
                      _handleYtProgressBarInteraction(
                          details.localPosition.dx, context, duration);
                    },
                    onHorizontalDragEnd: (details) {
                      _handleYtProgressBarInteraction(0, context, duration,
                          isEnd: true);
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Invisible touch area that extends upward for easier tapping
                        Container(
                          height: 15,
                          width: double.infinity,
                          color: Colors.transparent,
                        ),
                        // The actual progress bar - flush at bottom
                        Stack(
                          children: [
                            // Background track
                            Container(
                              height: 5,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.5),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(2.5),
                                  topRight: Radius.circular(2.5),
                                ),
                              ),
                            ),
                            // Blue progress
                            FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: progress,
                              child: Container(
                                height: 5,
                                decoration: const BoxDecoration(
                                  color: Colors.blue,
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(2.5),
                                    topRight: Radius.circular(2.5),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
      );

      final Widget yt = AspectRatio(
        aspectRatio: ytAspect,
        child: ytContent,
      );

      return VisibilityDetector(
        key: Key('video-yt-${widget.videoUrl}'),
        onVisibilityChanged: (visibilityInfo) {
          final isVisible = visibilityInfo.visibleFraction > 0.5;
          if (_isVisible != isVisible) {
            _isVisible = isVisible;
            try {
              if (isVisible) {
                if (_ytController?.value.isReady == true) {
                  _pauseOtherVideos(widget.videoUrl);
                  _ytController?.play();
                } else {
                  // Iframe still loading (preloaded offscreen): play as
                  // soon as it's ready — handled in _ytListener.
                  _ytWantsPlay = true;
                }
              } else {
                _ytWantsPlay = false;
                _ytController?.pause();
              }
            } catch (_) {}
          }
        },
        child: yt,
      );
    }

    // Use Android video player path
    if (_useAndroidVideoPlayer) {
      return _buildAndroidVideoPlayer(context);
    }

    // Calculate aspect ratio from the player state
    double aspectRatio = 9 / 16; // Default aspect ratio

    if (_mediaKitPlayer != null) {
      final videoWidth = _mediaKitPlayer!.state.width?.toDouble();
      final videoHeight = _mediaKitPlayer!.state.height?.toDouble();

      if (videoWidth != null &&
          videoHeight != null &&
          videoWidth > 0 &&
          videoHeight > 0) {
        // Use actual video dimensions
        aspectRatio = videoWidth / videoHeight;

        // Notify parent of aspect ratio update if needed
        if (widget.onAspectRatioUpdated != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              widget.onAspectRatioUpdated!(aspectRatio);
            }
          });
        }
      }
    }

    // Determine the actual widget size based on fullscreen state
    Widget videoWidget;
    if (_isFullscreen) {
      // In fullscreen, take up the entire screen in portrait mode
      videoWidget = Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        color: Colors.black,
        child: SafeArea(
          child: Center(
            child: AspectRatio(
              aspectRatio: aspectRatio,
              child: _mediaKitVideoController != null
                  ? Video(controller: _mediaKitVideoController!)
                  : Container(color: Colors.black),
            ),
          ),
        ),
      );
    } else {
      // Regular display with aspect ratio
      videoWidget = AspectRatio(
        aspectRatio: aspectRatio,
        child: Stack(
          children: [
            // The video player. Inline playback disables the built-in
            // gesture controls so drags scroll the feed instead of seeking;
            // seeking inline happens via the custom progress bar below.
            _mediaKitVideoController != null
                ? Video(
                    controller: _mediaKitVideoController!,
                    controls: widget.isFullscreen
                        ? AdaptiveVideoControls
                        : NoVideoControls,
                  )
                : Container(color: Colors.black),

            // Custom overlay for capturing tap to pause/play
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  if (_mediaKitPlayer != null) {
                    setState(() {
                      _showPlayPauseButton = true;
                    });

                    if (_mediaKitPlayer!.state.playing) {
                      _mediaKitPlayer!.pause();
                      _trackVideoPause();
                    } else {
                      _pauseOtherVideos(widget.videoUrl);
                      _mediaKitPlayer!.play();
                      _trackVideoStart();
                      // Ensure volume is set when manually playing
                      if (!VideoMuteManager.isMuted) {
                        _mediaKitPlayer!.setVolume(100);
                      }

                      // Auto-hide controls after playing
                      _startHideControlsTimer();
                    }
                  }
                },
                // Make this transparent to allow taps to go through to the video controls
                child: Container(color: Colors.transparent),
              ),
            ),

            // Play/Pause button in the center
            StreamBuilder<bool>(
              stream: _mediaKitPlayer?.stream.playing,
              initialData: false,
              builder: (context, snapshot) {
                final bool isPlaying = snapshot.data ?? false;

                return Positioned.fill(
                  child: AnimatedOpacity(
                    opacity: !isPlaying ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Center(
                      child: GestureDetector(
                        onTap: () {
                          if (_mediaKitPlayer != null) {
                            if (_mediaKitPlayer!.state.playing) {
                              _mediaKitPlayer!.pause();
                              _trackVideoPause();
                            } else {
                              _pauseOtherVideos(widget.videoUrl);
                              _mediaKitPlayer!.play();
                              _trackVideoStart();
                              // Ensure volume is set when manually playing
                              if (!VideoMuteManager.isMuted) {
                                _mediaKitPlayer!.setVolume(100);
                              }
                            }
                          }
                        },
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            // Mute button overlay
            Positioned(
              bottom: 60,
              right: 8,
              child: GestureDetector(
                onTap: () {
                  // Toggle the global mute state
                  VideoMuteManager.toggleMute();
                },
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Icon(
                    VideoMuteManager.isMuted
                        ? Icons.volume_off
                        : Icons.volume_up,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),

            // Timestamp overlay during scrubbing
            if (_isScrubbing)
              Positioned(
                bottom: 30,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _formatDuration(_scrubbingPosition),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),

            // Custom progress bar with blue color that supports seeking - positioned at the very bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: StreamBuilder<Duration>(
                stream: _mediaKitPlayer?.stream.position,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox();

                  final position = snapshot.data!;
                  final duration = _mediaKitPlayer?.state.duration ??
                      const Duration(seconds: 1);

                  // Calculate progress percentage
                  double progress =
                      position.inMilliseconds / duration.inMilliseconds;
                  progress = progress.clamp(0.0, 1.0);

                  return GestureDetector(
                    onTapDown: (details) {
                      _handleProgressBarInteraction(
                          details.localPosition.dx, context, duration,
                          isStart: true);
                    },
                    onTapUp: (details) {
                      _handleProgressBarInteraction(
                          details.localPosition.dx, context, duration,
                          isEnd: true);
                    },
                    onHorizontalDragStart: (details) {
                      _handleProgressBarInteraction(
                          details.localPosition.dx, context, duration,
                          isStart: true);
                    },
                    onHorizontalDragUpdate: (details) {
                      _handleProgressBarInteraction(
                          details.localPosition.dx, context, duration);
                    },
                    onHorizontalDragEnd: (details) {
                      _handleProgressBarInteraction(0, context, duration,
                          isEnd: true);
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Invisible touch area that extends upward for easier tapping
                        Container(
                          height: 15,
                          width: double.infinity,
                          color: Colors.transparent,
                        ),
                        // The actual progress bar - flush at bottom
                        Stack(
                          children: [
                            // Background track
                            Container(
                              height: 5,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.5),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(2.5),
                                  topRight: Radius.circular(2.5),
                                ),
                              ),
                            ),
                            // Blue progress
                            FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: progress,
                              child: Container(
                                height: 5,
                                decoration: const BoxDecoration(
                                  color: Colors.blue,
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(2.5),
                                    topRight: Radius.circular(2.5),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    // Show loading indicator
    if (_isLoading) {
      return Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 10),
              const Text(
                'Loading video...',
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  debugPrint('Retry button pressed');
                  _initializeVideo();
                },
                child:
                    const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    // Show error message if video is not playable
    if (!_isInitialized || !_isPlayable) {
      debugPrint(
          'Building error view - isInitialized: $_isInitialized, isPlayable: $_isPlayable');
      return Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        color: Colors.grey[300],
        child: Center(
          child: Text(
            _errorMessage,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return VisibilityDetector(
      key: Key('video-${widget.videoUrl}'),
      onVisibilityChanged: (visibilityInfo) {
        final isVisible = visibilityInfo.visibleFraction >
            0.5; // Increased threshold for better UX
        if (_isVisible != isVisible) {
          _isVisible = isVisible;
          if (_mediaKitPlayer != null && _isInitialized) {
            if (isVisible) {
              _pauseOtherVideos(widget.videoUrl);
              _mediaKitPlayer!.play();
              _trackVideoStart();
            } else {
              _mediaKitPlayer!.pause();
            }
          }
        }
      },
      child: videoWidget,
    );
  }

  @override
  void dispose() {
    debugPrint('Disposing VideoWidget for URL: ${widget.videoUrl}');
    // Remove observer
    WidgetsBinding.instance.removeObserver(this);

    // Cancel timers first to prevent any callbacks
    _loadingTimeoutTimer?.cancel();
    _scrubbingTimer?.cancel();
    _hideControlsTimer?.cancel();
    _trackingTimer?.cancel();

    // Cancel subscriptions to prevent memory leaks
    _muteSubscription?.cancel();
    _positionSubscription?.cancel();

    // Make sure to reset orientation and UI mode when disposing
    if (_isFullscreen) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
      );
    }

    // Remove from active players map before disposing
    _activePlayers.remove(widget.videoUrl);

    // Clear currently playing reference if this was the playing video
    if (_currentlyPlayingVideoUrl == widget.videoUrl) {
      _currentlyPlayingVideoUrl = null;
    }

    // Dispose Android video player
    if (_androidController != null) {
      try {
        _androidController!.dispose();
      } catch (e) {
        debugPrint('Error disposing Android video player: $e');
      }
      _androidController = null;
    }

    // Safely dispose the MediaKit player asynchronously.
    // CRITICAL: capture the VideoController reference so it is NOT
    // garbage-collected while mpv's native core_thread is still sending
    // events via FFI callbacks during mp_shutdown_clients.
    if (_mediaKitPlayer != null) {
      final playerToDispose = _mediaKitPlayer!;
      final controllerToKeepAlive = _mediaKitVideoController;
      _mediaKitPlayer = null;
      _mediaKitVideoController = null;

      Future.microtask(
        () =>
            _safeDisposeMediaKitPlayer(playerToDispose, controllerToKeepAlive),
      );
    }

    // Remove YouTube listener before disposing
    if (_ytListener != null && _ytController != null) {
      try {
        _ytController!.removeListener(_ytListener!);
      } catch (_) {}
    }

    try {
      _ytController?.dispose();
    } catch (_) {}

    super.dispose();
  }

  // Handle interaction with the progress bar (tap, drag start, drag update, drag end)
  void _handleProgressBarInteraction(
      double localX, BuildContext context, Duration duration,
      {bool isStart = false, bool isEnd = false}) {
    if (_mediaKitPlayer == null) return;

    if (isStart) {
      // Start scrubbing
      setState(() {
        _isScrubbing = true;
      });

      // Cancel any existing timer
      _scrubbingTimer?.cancel();
    }

    if (isEnd) {
      // End scrubbing - hide timestamp after a short delay
      _scrubbingTimer?.cancel();
      _scrubbingTimer = Timer(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _isScrubbing = false;
          });
        }
      });
      return;
    }

    // Get the width of the progress bar
    final RenderBox box = context.findRenderObject() as RenderBox;
    final double width = box.size.width;

    // Calculate the tap/drag position as a percentage
    double tapPosition = localX / width;
    tapPosition = tapPosition.clamp(0.0, 1.0);

    // Convert to duration
    final int milliseconds = (duration.inMilliseconds * tapPosition).round();
    final newPosition = Duration(milliseconds: milliseconds);

    // Update scrubbing position for timestamp display
    setState(() {
      _scrubbingPosition = newPosition;
    });

    // Seek to the new position
    _mediaKitPlayer!.seek(newPosition);
  }

  // Toggle play/pause for the YouTube player (used by the custom overlays,
  // since the WebView itself is behind IgnorePointer).
  void _toggleYoutubePlayPause() {
    if (_ytController == null) return;
    try {
      if (_ytController!.value.isPlaying) {
        _ytController!.pause();
        _trackVideoPause();
      } else {
        _pauseOtherVideos(widget.videoUrl);
        _ytController!.play();
        _trackVideoStart();
        // Ensure audio matches the global mute state when manually playing
        if (!VideoMuteManager.isMuted) {
          _ytController!.unMute();
        }
      }
    } catch (_) {}
    if (mounted) setState(() {});
  }

  // Handle interaction with the YouTube progress bar
  // (tap, drag start, drag update, drag end)
  void _handleYtProgressBarInteraction(
      double localX, BuildContext context, Duration duration,
      {bool isStart = false, bool isEnd = false}) {
    if (_ytController == null) return;

    if (isStart) {
      // Start scrubbing
      setState(() {
        _isScrubbing = true;
      });
      _scrubbingTimer?.cancel();
    }

    if (isEnd) {
      // End scrubbing - hide timestamp after a short delay
      _scrubbingTimer?.cancel();
      _scrubbingTimer = Timer(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _isScrubbing = false;
          });
        }
      });
      return;
    }

    // Get the width of the progress bar
    final RenderBox box = context.findRenderObject() as RenderBox;
    final double width = box.size.width;

    // Calculate the tap/drag position as a percentage
    double tapPosition = localX / width;
    tapPosition = tapPosition.clamp(0.0, 1.0);

    // Convert to duration
    final int milliseconds = (duration.inMilliseconds * tapPosition).round();
    final newPosition = Duration(milliseconds: milliseconds);

    // Update scrubbing position for timestamp display
    setState(() {
      _scrubbingPosition = newPosition;
    });

    // Seek to the new position
    try {
      _ytController!.seekTo(newPosition, allowSeekAhead: true);
    } catch (_) {}
  }

  // Format duration as mm:ss
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // Start timer to hide controls
  void _startHideControlsTimer() {
    // This function is now a no-op since we always show the play button when paused
    // and never show it when playing
  }

  // ==================== VIDEO TRACKING METHODS ====================

  void _updateWatchTime(Duration currentPosition) {
    final currentTime = DateTime.now();

    // Initialize video start time if not set
    _videoStartTime ??= currentTime;

    // Calculate time difference since last position update
    if (_lastPosition != Duration.zero) {
      final timeDiff = currentPosition - _lastPosition;
      if (timeDiff.inMilliseconds > 0 && timeDiff.inMilliseconds < 2000) {
        // Only add to watch time if it's a reasonable progression (less than 2 seconds)
        _totalWatchTime += timeDiff;
      }
    }

    _lastPosition = currentPosition;
  }

  void _trackVideoProgress(Duration currentPosition) {
    if (_mediaKitPlayer == null || widget.postId == null) return;

    final duration = _mediaKitPlayer!.state.duration;
    if (duration.inSeconds <= 0) return;

    final userId = AppsFlyerService().getCurrentUserId();
    if (userId == null) return;

    // Calculate watch percentage
    final watchPercent =
        (currentPosition.inMilliseconds / duration.inMilliseconds) * 100;

    // Track progress milestones (25%, 50%, 75%)
    const milestone25 = 25;
    const milestone50 = 50;
    const milestone75 = 75;
    const milestone95 = 95;

    if (watchPercent >= milestone25 &&
        !_trackedProgressMilestones.contains(milestone25)) {
      _trackedProgressMilestones.add(milestone25);
      _trackVideoMilestone(userId, currentPosition, duration, milestone25);
    }

    if (watchPercent >= milestone50 &&
        !_trackedProgressMilestones.contains(milestone50)) {
      _trackedProgressMilestones.add(milestone50);
      _trackVideoMilestone(userId, currentPosition, duration, milestone50);
    }

    if (watchPercent >= milestone75 &&
        !_trackedProgressMilestones.contains(milestone75)) {
      _trackedProgressMilestones.add(milestone75);
      _trackVideoMilestone(userId, currentPosition, duration, milestone75);
    }

    // Track completion at 95%
    if (watchPercent >= milestone95 && !_hasTrackedCompletion) {
      _hasTrackedCompletion = true;
      _trackVideoCompletion(userId, currentPosition, duration, true);
    }
  }

  void _trackVideoMilestone(String userId, Duration currentPosition,
      Duration duration, int milestone) {
    AppsFlyerService().trackVideoCompletion(
      postId: widget.postId!,
      userId: userId,
      watchedPercent: milestone.toDouble(),
      durationSeconds: duration.inSeconds,
      completed: false,
    );

    debugPrint('Video $milestone% milestone reached for ${widget.postId}');
  }

  void _trackVideoCompletion(String userId, Duration currentPosition,
      Duration duration, bool completed) {
    final watchPercent =
        (currentPosition.inMilliseconds / duration.inMilliseconds) * 100;

    AppsFlyerService().trackVideoCompletion(
      postId: widget.postId!,
      userId: userId,
      watchedPercent: watchPercent,
      durationSeconds: duration.inSeconds,
      completed: completed,
    );

    debugPrint(
        'Video completion tracked: ${watchPercent.toStringAsFixed(1)}% for ${widget.postId}');
  }

  // Track video engagement when user starts playing
  void _trackVideoStart() {
    if (widget.postId == null) return;

    final userId = AppsFlyerService().getCurrentUserId();
    if (userId == null) return;

    AppsFlyerService().logEvent('video_start', {
      'post_id': widget.postId!,
      'user_id': userId,
      'video_url': widget.videoUrl,
      'category': widget.category,
      'author_id': widget.authorId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    debugPrint('Video start tracked for ${widget.postId}');
  }

  // Track video pause
  void _trackVideoPause() {
    if (widget.postId == null) return;

    final userId = AppsFlyerService().getCurrentUserId();
    if (userId == null) return;

    final currentPosition = _mediaKitPlayer?.state.position ?? Duration.zero;
    final duration = _mediaKitPlayer?.state.duration ?? Duration.zero;

    if (duration.inSeconds > 0) {
      final watchPercent =
          (currentPosition.inMilliseconds / duration.inMilliseconds) * 100;

      AppsFlyerService().logEvent('video_pause', {
        'post_id': widget.postId!,
        'user_id': userId,
        'pause_at_percent': watchPercent,
        'pause_at_seconds': currentPosition.inSeconds,
        'total_watch_time_seconds': _totalWatchTime.inSeconds,
        'video_url': widget.videoUrl,
        'category': widget.category,
        'author_id': widget.authorId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      debugPrint(
          'Video pause tracked at ${watchPercent.toStringAsFixed(1)}% for ${widget.postId}');
    }
  }
}

// Helper function to avoid Completer warnings
void unawaited(Future<void> future) {}
