import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:visibility_detector/visibility_detector.dart';

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

// 비디오 플레이어 캐시를 위한 전역 맵
final Map<String, Player> _cachedPlayers = {};
final Map<String, VideoController> _cachedControllers = {};
final Map<String, bool> _cachedInitStatus = {};

class VideoWidget extends StatefulWidget {
  final String videoUrl;
  final Function(double)? onAspectRatioUpdated;

  const VideoWidget({
    super.key,
    required this.videoUrl,
    this.onAspectRatioUpdated,
  });

  @override
  _VideoWidgetState createState() => _VideoWidgetState();
}

class _VideoWidgetState extends State<VideoWidget> {
  Player? _mediaKitPlayer;
  VideoController? _mediaKitVideoController;
  bool _isInitialized = false;
  bool _isPlayable = true;
  bool _isLoading = true;
  Timer? _loadingTimeoutTimer;
  String _errorMessage = 'Unsupported video format.';
  final String _uniqueViewId = UniqueKey().toString();

  // Add scrubbing state variables
  bool _isScrubbing = false;
  Duration _scrubbingPosition = Duration.zero;
  Timer? _scrubbingTimer;

  // Control visibility of play/pause button
  bool _showPlayPauseButton = true;
  Timer? _hideControlsTimer;

  // Subscription to mute state changes
  StreamSubscription? _muteSubscription;
  StreamSubscription? _positionSubscription;

  @override
  void initState() {
    super.initState();

    // 이미 캐시된 플레이어가 있는지 확인
    if (_cachedPlayers.containsKey(widget.videoUrl) &&
        _cachedControllers.containsKey(widget.videoUrl) &&
        _cachedInitStatus[widget.videoUrl] == true) {
      debugPrint('Using cached player for URL: ${widget.videoUrl}');
      _mediaKitPlayer = _cachedPlayers[widget.videoUrl];
      _mediaKitVideoController = _cachedControllers[widget.videoUrl];
      _isInitialized = true;
      _isLoading = false;

      // 비디오 크기 정보가 있으면 바로 비율 업데이트
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _mediaKitPlayer != null) {
          final videoWidth = _mediaKitPlayer!.state.width?.toDouble();
          final videoHeight = _mediaKitPlayer!.state.height?.toDouble();

          if (videoWidth != null &&
              videoHeight != null &&
              videoWidth > 0 &&
              videoHeight > 0 &&
              widget.onAspectRatioUpdated != null) {
            final aspectRatio = videoWidth / videoHeight;
            widget.onAspectRatioUpdated!(aspectRatio);
          }
        }
      });

      // 볼륨 상태 동기화
      if (_mediaKitPlayer != null) {
        _mediaKitPlayer!.setVolume(VideoMuteManager.isMuted ? 0 : 100);
      }
    } else {
      _initializeVideo();
    }

    // Set a manual timeout for loading to prevent infinite spinner
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
    });

    // Apply current global mute state
    if (_mediaKitPlayer != null) {
      _mediaKitPlayer!.setVolume(VideoMuteManager.isMuted ? 0 : 100);
    }
  }

  Future<void> _initializeVideo() async {
    setState(() {
      _isLoading = true;
      _isPlayable = true;
    });

    // Process the URL to handle YouTube links
    String mediaUrl = widget.videoUrl;

    // Check if it's a YouTube URL and extract the video ID
    if (_isYoutubeUrl(widget.videoUrl)) {
      final videoId = _getYoutubeVideoId(widget.videoUrl);
      if (videoId != null) {
        // Convert to direct playable URL that MediaKit can handle
        mediaUrl = 'https://www.youtube.com/watch?v=$videoId';
      } else {
        setState(() {
          _isPlayable = false;
          _isLoading = false;
          _errorMessage = 'Invalid YouTube URL';
        });
        return;
      }
    }

    // Initialize MediaKit player for all video types
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
      // Dispose any existing MediaKit player if not cached
      if (_mediaKitPlayer != null &&
          !_cachedPlayers.containsKey(widget.videoUrl)) {
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
      final playerStateStream = _mediaKitPlayer!.stream.playing;
      final subscription = playerStateStream.listen((playing) {
        if (!mediaKitCompleter.isCompleted) {
          mediaKitCompleter.complete();
        }
      });

      // 비디오 위치 업데이트를 통해 크기 정보를 더 빠르게 확인
      _positionSubscription = _mediaKitPlayer!.stream.position.listen((_) {
        if (mounted) {
          final videoWidth = _mediaKitPlayer!.state.width?.toDouble();
          final videoHeight = _mediaKitPlayer!.state.height?.toDouble();

          if (videoWidth != null &&
              videoHeight != null &&
              videoWidth > 0 &&
              videoHeight > 0) {
            debugPrint('Early video dimensions: ${videoWidth}x$videoHeight');
            final aspectRatio = videoWidth / videoHeight;
            if (widget.onAspectRatioUpdated != null) {
              widget.onAspectRatioUpdated!(aspectRatio);
            }

            // 비디오 크기를 확인했으면 캐시에 이 플레이어를 추가
            if (!_cachedPlayers.containsKey(widget.videoUrl)) {
              _cachedPlayers[widget.videoUrl] = _mediaKitPlayer!;
              _cachedControllers[widget.videoUrl] = _mediaKitVideoController!;
              _cachedInitStatus[widget.videoUrl] = true;
              debugPrint('Player cached for URL: ${widget.videoUrl}');
            }
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
      unawaited(_mediaKitPlayer!.open(Media(videoPath)));

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
      _mediaKitPlayer!.pause();

      // 비디오가 로드되었고 캐시에 없다면 캐시에 추가
      if (!_cachedPlayers.containsKey(widget.videoUrl)) {
        _cachedPlayers[widget.videoUrl] = _mediaKitPlayer!;
        _cachedControllers[widget.videoUrl] = _mediaKitVideoController!;
        _cachedInitStatus[widget.videoUrl] = true;
        debugPrint('Player cached for URL: ${widget.videoUrl}');
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

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width - 60;
    // 기본 비율을 정사각형(1:1)으로 설정
    double aspectRatio = 1;

    if (_mediaKitPlayer != null) {
      final videoWidth = _mediaKitPlayer!.state.width?.toDouble();
      final videoHeight = _mediaKitPlayer!.state.height?.toDouble();

      if (videoWidth != null &&
          videoHeight != null &&
          videoWidth > 0 &&
          videoHeight > 0) {
        // 실제 비디오 치수 사용
        aspectRatio = videoWidth / videoHeight;
        debugPrint(
            'Video dimensions: ${videoWidth}x$videoHeight, aspect ratio: $aspectRatio');

        // 부모에게 종횡비 정보 전달
        if (widget.onAspectRatioUpdated != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              widget.onAspectRatioUpdated!(aspectRatio);
            }
          });
        }

        // 종횡비 알림 발송
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            VideoAspectRatioNotification(aspectRatio).dispatch(context);
          }
        });
      }
    }

    // Show loading indicator
    if (_isLoading) {
      return Container(
        width: width,
        height: width / aspectRatio,
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
        width: width,
        height: width / aspectRatio,
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

    // Display video with MediaKit's controls
    return VisibilityDetector(
      key: Key(widget.videoUrl),
      onVisibilityChanged: (info) {
        if (!mounted) return;

        if (info.visibleFraction > 0.7) {
          // Auto-play when video becomes sufficiently visible
          if (_mediaKitPlayer != null) {
            _mediaKitPlayer!.play();
            // Ensure volume is set according to global mute state when playing
            _mediaKitPlayer!.setVolume(VideoMuteManager.isMuted ? 0 : 100);
          }
        } else if (info.visibleFraction == 0) {
          // Pause when video is not visible
          if (_mediaKitPlayer != null && _mediaKitPlayer!.state.playing) {
            _mediaKitPlayer!.pause();
          }
        }
      },
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Stack(
          children: [
            // The video player
            Video(controller: _mediaKitVideoController!),

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
                    } else {
                      _mediaKitPlayer!.play();
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
                            } else {
                              _mediaKitPlayer!.play();
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
                          child: const Icon(
                            Icons.play_arrow,
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
              bottom: 10,
              right: 10,
              child: GestureDetector(
                onTap: () {
                  // Toggle the global mute state
                  VideoMuteManager.toggleMute();
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    shape: BoxShape.circle,
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
      ),
    );
  }

  @override
  void dispose() {
    debugPrint('Disposing VideoWidget for URL: ${widget.videoUrl}');
    // Cancel timers
    _loadingTimeoutTimer?.cancel();
    _scrubbingTimer?.cancel();
    _hideControlsTimer?.cancel();

    // Cancel mute state subscription
    _muteSubscription?.cancel();
    _positionSubscription?.cancel();

    // 캐시된 플레이어는 계속 유지, 캐시되지 않은 플레이어만 dispose
    if (_mediaKitPlayer != null &&
        !_cachedPlayers.containsKey(widget.videoUrl)) {
      _mediaKitPlayer!.pause();
      _mediaKitPlayer!.dispose();
      _mediaKitPlayer = null;
    } else if (_mediaKitPlayer != null) {
      // 캐시된 플레이어는 일시 정지만 함
      _mediaKitPlayer!.pause();
    }

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
}

// Helper function to avoid Completer warnings
void unawaited(Future<void> future) {}
