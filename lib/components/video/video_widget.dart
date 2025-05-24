import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:visibility_detector/visibility_detector.dart';

// Notification to communicate video aspect ratio to parent widgets
class VideoAspectRatioNotification extends Notification {
  final double aspectRatio;
  
  VideoAspectRatioNotification(this.aspectRatio);
}

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

  @override
  void initState() {
    super.initState();
    _initializeVideo();
    
    // Set a manual timeout for loading to prevent infinite spinner
    _loadingTimeoutTimer = Timer(const Duration(seconds: 15), () {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
          _isPlayable = false;
          _errorMessage = 'Video loading timed out. Please check your connection and try again.';
        });
      }
    });
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
      // Dispose any existing MediaKit player
      if (_mediaKitPlayer != null) {
        await _mediaKitPlayer!.dispose();
        _mediaKitPlayer = null;
        _mediaKitVideoController = null;
      }
      
      // Initialize the player with configuration for showing controls
      _mediaKitPlayer = Player();
      
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
          throw TimeoutException('MediaKit initialization timed out after 10 seconds');
        },
      );
      
      // Cancel subscription after we're done
      subscription.cancel();
      
      debugPrint('MediaKit Player opened successfully');
      _mediaKitPlayer!.pause();

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
          _errorMessage = 'Video loading error: ${e.toString().substring(0, math.min(100, e.toString().length))}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width - 60;
    double aspectRatio = 16 / 9; // Default fallback aspect ratio
    
    if (_mediaKitPlayer != null) {
      final videoWidth = _mediaKitPlayer!.state.width?.toDouble();
      final videoHeight = _mediaKitPlayer!.state.height?.toDouble();
      
      if (videoWidth != null && videoHeight != null && videoWidth > 0 && videoHeight > 0) {
        aspectRatio = videoWidth / videoHeight;

        // Call the callback to inform parent about aspect ratio
        if (widget.onAspectRatioUpdated != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              widget.onAspectRatioUpdated!(aspectRatio);
            }
          });
        }
        
        // Dispatch notification with aspect ratio
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            VideoAspectRatioNotification(aspectRatio).dispatch(context);
          }
        });
      } else {}
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
                child: const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    // Show error message if video is not playable
    if (!_isInitialized || !_isPlayable) {
      debugPrint('Building error view - isInitialized: $_isInitialized, isPlayable: $_isPlayable');
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
                    if (_mediaKitPlayer!.state.playing) {
                      _mediaKitPlayer!.pause();
                    } else {
                      _mediaKitPlayer!.play();
                    }
                  }
                },
                // Make this transparent to allow taps to go through to the video controls
                child: Container(color: Colors.transparent),
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
                  final duration = _mediaKitPlayer?.state.duration ?? const Duration(seconds: 1);
                  
                  // Calculate progress percentage
                  double progress = position.inMilliseconds / duration.inMilliseconds;
                  progress = progress.clamp(0.0, 1.0);
                  
                  return GestureDetector(
                    onTapDown: (details) {
                      _handleProgressBarTap(details.localPosition.dx, context, duration);
                    },
                    onHorizontalDragUpdate: (details) {
                      _handleProgressBarTap(details.localPosition.dx, context, duration);
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
    // Cancel timer
    _loadingTimeoutTimer?.cancel();
    
    // Dispose of the media kit player
    if (_mediaKitPlayer != null) {
      _mediaKitPlayer!.pause();
      _mediaKitPlayer!.dispose();
      _mediaKitPlayer = null;
    }

    super.dispose();
  }

  // Handle tap on the progress bar to seek
  void _handleProgressBarTap(double localX, BuildContext context, Duration duration) {
    if (_mediaKitPlayer == null) return;
    
    // Get the width of the progress bar
    final RenderBox box = context.findRenderObject() as RenderBox;
    final double width = box.size.width;
    
    // Calculate the tap position as a percentage
    double tapPosition = localX / width;
    tapPosition = tapPosition.clamp(0.0, 1.0);
    
    // Convert to duration
    final int milliseconds = (duration.inMilliseconds * tapPosition).round();
    final newPosition = Duration(milliseconds: milliseconds);
    
    // Seek to the new position
    _mediaKitPlayer!.seek(newPosition);
  }
  
  // Format duration as mm:ss
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

// Helper function to avoid Completer warnings
void unawaited(Future<void> future) {}
