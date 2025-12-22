import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
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

// Track all active players for pausing others when a new video plays
final Map<String, Player> _activePlayers = {};

// Track currently playing video
String? _currentlyPlayingVideoUrl;

void disposeAllVideoCache() {
  try {
    for (final player in _activePlayers.values) {
      player.dispose();
    }
    _activePlayers.clear();
    _currentlyPlayingVideoUrl = null;
    debugPrint('All video players disposed');
  } catch (e) {
    debugPrint('Error disposing all video players: $e');
  }
}

// Pause all videos except the specified URL
void _pauseOtherVideos(String currentVideoUrl) {
  if (_currentlyPlayingVideoUrl == currentVideoUrl) return;

  // Pause the previously playing video
  if (_currentlyPlayingVideoUrl != null) {
    final previousPlayer = _activePlayers[_currentlyPlayingVideoUrl];
    if (previousPlayer != null && previousPlayer.state.playing) {
      previousPlayer.pause();
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

  const VideoWidget({
    super.key,
    required this.videoUrl,
    this.onAspectRatioUpdated,
    this.postId,
    this.category,
    this.authorId,
  });

  @override
  _VideoWidgetState createState() => _VideoWidgetState();
}

class _VideoWidgetState extends State<VideoWidget> with WidgetsBindingObserver {
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
      if (_mediaKitPlayer != null && mounted) {
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
    if (_mediaKitPlayer != null) {
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
      if (_mediaKitPlayer != null && _mediaKitPlayer!.state.playing) {
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
        try {
          _ytController?.dispose();
        } catch (_) {}
        _ytController = YoutubePlayerController(
          initialVideoId: videoId,
          flags: YoutubePlayerFlags(
            autoPlay: true,
            mute: VideoMuteManager.isMuted,
            disableDragSeek: false,
            loop: false,
            isLive: false,
            forceHD: false,
            enableCaption: false,
            useHybridComposition: true,
          ),
        );

        _ytListener = () {
          try {
            final d = _ytController!.value.metaData.duration;
            if (d.inSeconds > 0) {
              final detectedShorts = d.inSeconds <= 65;
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

    // Initialize MediaKit player for non-YouTube video types
    await _initializeMediaKitPlayer(mediaUrl);
  }

  bool _isYoutubeUrl(String url) {
    // Check if the URL contains youtube.com or youtu.be
    return url.contains('youtube.com') || url.contains('youtu.be');
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
      // Dispose any existing MediaKit player before creating a new one
      if (_mediaKitPlayer != null) {
        await _mediaKitPlayer!.dispose();
        _mediaKitPlayer = null;
        _mediaKitVideoController = null;
      }

      // Initialize the player with configuration for showing controls
      _mediaKitPlayer = Player();

      // Set volume immediately before opening media
      await _mediaKitPlayer!.setVolume(VideoMuteManager.isMuted ? 0 : 100);

      // Create video controller with the proper configuration for the platform
      _mediaKitVideoController = VideoController(
        _mediaKitPlayer!,
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

      debugPrint('MediaKit Player opened successfully');

      // Register this player in active players map for pausing other videos
      _activePlayers[widget.videoUrl] = _mediaKitPlayer!;

      // Enable autoplay - start playing automatically when initialized
      _pauseOtherVideos(widget.videoUrl);
      _mediaKitPlayer!.play();

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
        showVideoProgressIndicator: true,
      );

      final Widget yt = AspectRatio(
        aspectRatio: ytAspect,
        child: Stack(
          children: [
            Positioned.fill(child: ytCore),
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
          ],
        ),
      );

      return VisibilityDetector(
        key: Key('video-yt-${widget.videoUrl}'),
        onVisibilityChanged: (visibilityInfo) {
          final isVisible = visibilityInfo.visibleFraction > 0.5;
          if (_isVisible != isVisible) {
            _isVisible = isVisible;
            try {
              if (isVisible) {
                _pauseOtherVideos(widget.videoUrl);
                _ytController?.play();
              } else {
                _ytController?.pause();
              }
            } catch (_) {}
          }
        },
        child: yt,
      );
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
            // The video player
            _mediaKitVideoController != null
                ? Video(controller: _mediaKitVideoController!)
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

            // // Full screen button
            // Positioned(
            //   bottom: 10,
            //   right: 56, // Position it to the left of the mute button
            //   child: GestureDetector(
            //     onTap: () {
            //       // Toggle fullscreen
            //       if (_mediaKitPlayer != null) {
            //         setState(() {
            //           _isFullscreen = !_isFullscreen;
            //         });

            //         if (_isFullscreen) {
            //           // Enter fullscreen mode - always use portrait orientation
            //           SystemChrome.setPreferredOrientations([
            //             DeviceOrientation.portraitUp,
            //           ]);

            //           SystemChrome.setEnabledSystemUIMode(
            //             SystemUiMode.immersiveSticky,
            //           );
            //         } else {
            //           // Exit fullscreen mode
            //           SystemChrome.setPreferredOrientations([
            //             DeviceOrientation.portraitUp,
            //           ]);
            //           SystemChrome.setEnabledSystemUIMode(
            //             SystemUiMode.edgeToEdge,
            //           );
            //         }
            //       }
            //     },
            //     child: Container(
            //       width: 36,
            //       height: 36,
            //       decoration: BoxDecoration(
            //         color: Colors.black.withOpacity(0.6),
            //         shape: BoxShape.circle,
            //       ),
            //       child: Icon(
            //         _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
            //         color: Colors.white,
            //         size: 20,
            //       ),
            //     ),
            //   ),
            // ),

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

    // Always dispose the player when widget is disposed
    if (_mediaKitPlayer != null) {
      try {
        _mediaKitPlayer!.dispose();
      } catch (e) {
        debugPrint('Error disposing media player: $e');
      }
    }

    // Clear references to prevent memory leaks
    _mediaKitPlayer = null;
    _mediaKitVideoController = null;

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
