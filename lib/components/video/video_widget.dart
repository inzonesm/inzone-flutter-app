import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
//import 'package:ffmpeg_kit_flutter_full/ffprobe_kit.dart';

// This variable tracks if a YouTube fullscreen player is currently active
// to prevent multiple instances from being created simultaneously
bool _isYoutubeFullscreenActive = false;

// This keeps track of which YouTube players are currently initialized
// to prevent recreation of views with the same ID
final Map<String, bool> _activeYoutubeViews = {};

class VideoWidget extends StatefulWidget {
  final String videoUrl;

  const VideoWidget({super.key, required this.videoUrl});

  @override
  _VideoWidgetState createState() => _VideoWidgetState();
}

class _VideoWidgetState extends State<VideoWidget> {
  VideoPlayerController? _videoPlayerController;
  Player? _mediaKitPlayer;
  VideoController? _mediaKitVideoController;
  YoutubePlayerController? _youtubePlayerController;
  bool _isInitialized = false;
  bool _isPlayable = true;
  bool _isLoading = true;
  bool _showControls = true;
  bool _useMediaKit = false;
  bool _isYoutubeVideo = false;
  Timer? _hideControlsTimer;
  String? _youtubeVideoId;
  final String _uniqueViewId = UniqueKey().toString();

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    setState(() {
      _isLoading = true;
      _isPlayable = true;
    });

    // Check if URL is a YouTube video
    if (_isYoutubeUrl(widget.videoUrl)) {
      _initializeYoutubePlayer(widget.videoUrl);
    } else {
      _analyzeAndInitializeVideo();
    }
  }

  bool _isYoutubeUrl(String url) {
    // Check if the URL contains youtube.com or youtu.be
    return url.contains('youtube.com') || url.contains('youtu.be');
  }

  String? _getYoutubeVideoId(String url) {
    return YoutubePlayer.convertUrlToId(url);
  }

  void _initializeYoutubePlayer(String url) {
    _youtubeVideoId = _getYoutubeVideoId(url);

    if (_youtubeVideoId != null) {
      // Check if this view is already active
      if (_activeYoutubeViews[_youtubeVideoId] == true) {
        // Wait a bit and try again to avoid view ID collision
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _initializeYoutubePlayer(url);
          }
        });
        return;
      }

      _youtubePlayerController = YoutubePlayerController(
        initialVideoId: _youtubeVideoId!,
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          mute: true,
          enableCaption: true,
          hideControls: false,
          forceHD: true,
        ),
      );

      // Mark this YouTube view as active
      _activeYoutubeViews[_youtubeVideoId!] = true;

      setState(() {
        _isYoutubeVideo = true;
        _isInitialized = true;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isPlayable = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _analyzeAndInitializeVideo() async {
    // 간단한 URL 확장자 분석을 기반으로 코덱 판단
    String fileExtension = widget.videoUrl.split('.').last.toLowerCase();

    // VP9 코덱과 연관된 확장자인 경우 MediaKit 사용
    if (fileExtension == 'webm') {
      _useMediaKit = true;
      await _initializeMediaKitPlayer(widget.videoUrl);
    } else {
      // 기본 VideoPlayer 사용
      await _initializeVideoPlayer(widget.videoUrl);
    }
  }

  // FFprobeKit 사용하지 않고 간단한 미디어 타입 확인 함수로 대체
  String getMediaType(String url) {
    final extension = url.split('.').last.toLowerCase();
    switch (extension) {
      case 'mp4':
        return 'video/mp4';
      case 'webm':
        return 'video/webm';
      case 'mkv':
        return 'video/x-matroska';
      case 'mov':
        return 'video/quicktime';
      default:
        return 'video/mp4'; // 기본값
    }
  }

  Future<void> _initializeVideoPlayer(String videoPath) async {
    _videoPlayerController =
        VideoPlayerController.networkUrl(Uri.parse(videoPath));

    try {
      await _videoPlayerController!.initialize();
      _videoPlayerController!.pause();
      setState(() {
        _isInitialized = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isPlayable = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _initializeMediaKitPlayer(String videoPath) async {
    try {
      _mediaKitPlayer = Player();
      _mediaKitVideoController = VideoController(_mediaKitPlayer!);
      await _mediaKitPlayer!.open(Media(videoPath));
      _mediaKitPlayer!.pause();

      setState(() {
        _isInitialized = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isPlayable = false;
        _isLoading = false;
      });
    }
  }

  void _togglePlayback() {
    if (_isYoutubeVideo && _youtubePlayerController != null) {
      if (_youtubePlayerController!.value.isPlaying) {
        _youtubePlayerController!.pause();
      } else {
        _youtubePlayerController!.play();
      }
    } else if (_useMediaKit && _mediaKitPlayer != null) {
      if (_mediaKitPlayer!.state.playing) {
        _mediaKitPlayer!.pause();
      } else {
        _mediaKitPlayer!.play();
      }
    } else if (_videoPlayerController != null) {
      setState(() {
        if (_videoPlayerController!.value.isPlaying) {
          _videoPlayerController!.pause();
        } else {
          _videoPlayerController!.play();
        }
      });
    }
  }

  void _toggleControls() {
    // Don't toggle controls for YouTube videos as they have their own controls
    if (_isYoutubeVideo) return;

    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _hideControlsTimer?.cancel();
      _hideControlsTimer = Timer(const Duration(seconds: 3), () {
        setState(() {
          _showControls = false;
        });
      });
    }
  }

  double _getDuration() {
    if (_isYoutubeVideo && _youtubePlayerController != null) {
      return _youtubePlayerController!.metadata.duration.inSeconds.toDouble();
    } else if (_useMediaKit && _mediaKitPlayer != null) {
      return _mediaKitPlayer!.state.duration.inSeconds.toDouble();
    } else if (_videoPlayerController != null) {
      return _videoPlayerController!.value.duration.inSeconds.toDouble();
    }
    return 1.0;
  }

  double _currentPosition() {
    if (_isYoutubeVideo && _youtubePlayerController != null) {
      return _youtubePlayerController!.value.position.inSeconds.toDouble();
    } else if (_useMediaKit && _mediaKitPlayer != null) {
      return _mediaKitPlayer!.state.position.inSeconds.toDouble();
    } else if (_videoPlayerController != null) {
      return _videoPlayerController!.value.position.inSeconds.toDouble();
    }
    return 0.0;
  }

  void _seekTo(double seconds) {
    if (_isYoutubeVideo && _youtubePlayerController != null) {
      _youtubePlayerController!.seekTo(Duration(seconds: seconds.toInt()));
    } else if (_useMediaKit && _mediaKitPlayer != null) {
      _mediaKitPlayer!.seek(Duration(seconds: seconds.toInt()));
    } else if (_videoPlayerController != null) {
      _videoPlayerController!.seekTo(Duration(seconds: seconds.toInt()));
    }
  }

  void _openFullscreenYoutube() {
    if (_youtubeVideoId != null && !_isYoutubeFullscreenActive) {
      // Set the global flag to prevent multiple instances
      _isYoutubeFullscreenActive = true;

      // Pause the current player to avoid having multiple active players
      if (_youtubePlayerController != null) {
        _youtubePlayerController!.pause();
      }

      // Store the current position before navigating
      final Duration currentPosition =
          _youtubePlayerController?.value.position ?? Duration.zero;

      Navigator.of(context)
          .push(
        MaterialPageRoute(
          builder: (context) => FullscreenYoutubePlayer(
            videoId: _youtubeVideoId!,
            startAt: currentPosition,
          ),
        ),
      )
          .then((_) {
        // Reset the flag when returning from fullscreen
        _isYoutubeFullscreenActive = false;

        // Resume normal playback if the widget is still mounted
        if (mounted && _youtubePlayerController != null) {
          // Wait a short delay to ensure the fullscreen player is fully disposed
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted && _youtubePlayerController != null) {
              _youtubePlayerController!.play();
            }
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width - 60;
    double aspectRatio = 16 / 9; // Fallback

    double defaultWidth = 16;
    double defaultHeight = 9;

    if (_useMediaKit && _mediaKitPlayer != null) {
      final width = _mediaKitPlayer!.state.width?.toDouble() ?? defaultWidth;
      final height = _mediaKitPlayer!.state.height?.toDouble() ?? defaultHeight;
      aspectRatio = width / height;
    } else if (_videoPlayerController != null) {
      aspectRatio = _videoPlayerController!.value.aspectRatio;
    }
    aspectRatio =
        defaultWidth / defaultHeight; // Final fallback in case both are null

    // Show loading indicator
    if (_isLoading) {
      return Container(
        width: width,
        height: width / aspectRatio,
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Show error message if video is not playable
    if (!_isInitialized || !_isPlayable) {
      return Container(
        width: width,
        height: width / aspectRatio,
        color: Colors.grey[300],
        child: const Center(
          child: Text(
            'Unsupported video format.',
            style: TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    // Return YouTube player if it's a YouTube video
    if (_isYoutubeVideo && _youtubePlayerController != null) {
      return VisibilityDetector(
        key: Key('youtube-${widget.videoUrl}'),
        onVisibilityChanged: (info) {
          if (mounted && _youtubePlayerController != null) {
            if (info.visibleFraction > 0.7) {
              // Auto-play when video becomes visible
              _youtubePlayerController!.play();
            } else if (info.visibleFraction == 0 &&
                _youtubePlayerController!.value.isPlaying) {
              _youtubePlayerController!.pause();
            }
          }
        },
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            children: [
              YoutubePlayer(
                controller: _youtubePlayerController!,
                showVideoProgressIndicator: true,
                progressIndicatorColor: Colors.red,
                progressColors: const ProgressBarColors(
                  playedColor: Colors.red,
                  handleColor: Colors.redAccent,
                ),
                onEnded: (metaData) {
                  if (mounted && _youtubePlayerController != null) {
                    _youtubePlayerController!.pause();
                  }
                },
              ),
              // Custom fullscreen button overlay
              Positioned(
                bottom: 0,
                right: 0,
                child: IconButton(
                  icon: const Icon(
                    Icons.fullscreen,
                    color: Colors.white,
                    size: 30,
                  ),
                  onPressed: _openFullscreenYoutube,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Regular video player
    return VisibilityDetector(
      key: Key(widget.videoUrl),
      onVisibilityChanged: (info) {
        if (!mounted) return;

        if (info.visibleFraction > 0.7) {
          // Auto-play when video becomes sufficiently visible
          if (_useMediaKit && _mediaKitPlayer != null) {
            _mediaKitPlayer!.play();
            // Hide controls after starting playback
            setState(() {
              _showControls = false;
            });
          } else if (_videoPlayerController != null) {
            _videoPlayerController!.play();
            // Hide controls after starting playback
            setState(() {
              _showControls = false;
            });
          }
        } else if (info.visibleFraction == 0) {
          // Pause when video is not visible
          if (_useMediaKit && _mediaKitPlayer != null) {
            _mediaKitPlayer!.pause();
          } else if (_videoPlayerController != null &&
              _videoPlayerController!.value.isPlaying) {
            _videoPlayerController!.pause();
          }
        }
      },
      child: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AspectRatio(
              aspectRatio: aspectRatio,
              child: _useMediaKit
                  ? Video(controller: _mediaKitVideoController!)
                  : VideoPlayer(_videoPlayerController!),
            ),
            if (_showControls)
              Positioned.fill(
                child: Container(
                  color: Colors.black54,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(
                          _isPlaying() ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 48.0,
                        ),
                        onPressed: _togglePlayback,
                      ),
                      // Slider(
                      //   value: _currentPosition(),
                      //   min: 0,
                      //   max: _getDuration(),
                      //   onChanged: _seekTo,
                      //   activeColor: Colors.red,
                      //   inactiveColor: Colors.white,
                      // ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool _isPlaying() {
    if (_isYoutubeVideo && _youtubePlayerController != null) {
      return _youtubePlayerController!.value.isPlaying;
    } else if (_useMediaKit && _mediaKitPlayer != null) {
      return _mediaKitPlayer!.state.playing;
    } else if (_videoPlayerController != null) {
      return _videoPlayerController!.value.isPlaying;
    }
    return false;
  }

  @override
  void dispose() {
    // Cancel the timer to prevent setState calls after dispose
    _hideControlsTimer?.cancel();

    // Dispose of the YouTube player controller
    if (_youtubePlayerController != null && _youtubeVideoId != null) {
      _youtubePlayerController!.pause();
      _youtubePlayerController!.dispose();
      // Remove this view from active views
      _activeYoutubeViews.remove(_youtubeVideoId);
      _youtubePlayerController = null;
    }

    // Dispose of the video player controllers
    if (_videoPlayerController != null) {
      _videoPlayerController!.pause();
      _videoPlayerController!.dispose();
      _videoPlayerController = null;
    }

    // Dispose of the media kit player
    if (_mediaKitPlayer != null) {
      _mediaKitPlayer!.pause();
      _mediaKitPlayer!.dispose();
      _mediaKitPlayer = null;
    }

    super.dispose();
  }
}

class FullscreenYoutubePlayer extends StatefulWidget {
  final String videoId;
  final Duration startAt;

  const FullscreenYoutubePlayer({
    super.key,
    required this.videoId,
    required this.startAt,
  });

  @override
  _FullscreenYoutubePlayerState createState() =>
      _FullscreenYoutubePlayerState();
}

class _FullscreenYoutubePlayerState extends State<FullscreenYoutubePlayer>
    with WidgetsBindingObserver {
  late YoutubePlayerController _controller;
  bool _isControllerInitialized = false;

  @override
  void initState() {
    super.initState();

    // Add observer for lifecycle events
    WidgetsBinding.instance.addObserver(this);

    // Set orientation to portrait for reels-like experience
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // Hide status bar
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
    );

    // Wait a short delay before initializing the controller to avoid view ID conflicts
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _controller = YoutubePlayerController(
          initialVideoId: widget.videoId,
          flags: YoutubePlayerFlags(
            autoPlay: true,
            mute: false,
            hideControls: false,
            enableCaption: true,
            startAt: widget.startAt.inSeconds,
          ),
        );

        // 컨트롤러 초기화 후 unmute
        _controller.addListener(() {
          if (_controller.value.hasPlayed && _controller.value.volume == 0) {
            _controller.unMute();
          }
        });

        if (mounted) {
          setState(() {
            _isControllerInitialized = true;
          });
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Ensure orientation is locked to portrait when app is resumed
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    } else if (state == AppLifecycleState.paused) {
      // Pause video when app goes to background
      if (_isControllerInitialized) {
        _controller.pause();
      }
    }
  }

  void _exitFullscreen() async {
    // Pause the player
    if (_isControllerInitialized) {
      _controller.pause();
    }

    // Reset orientation and show system UI before popping
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
    );

    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _exitFullscreen();
        // Return false to prevent the default back behavior
        // as we're handling navigation manually
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              // Center the YouTube player to achieve a reels-like experience
              Center(
                child: _isControllerInitialized
                    ? SizedBox(
                        // Use screen width for a full portrait view like reels
                        width: MediaQuery.of(context).size.width,
                        // Match the YouTube video player height with aspect ratio
                        height: MediaQuery.of(context).size.width * (16 / 9),
                        child: YoutubePlayer(
                          controller: _controller,
                          showVideoProgressIndicator: true,
                          progressIndicatorColor: Colors.red,
                          progressColors: const ProgressBarColors(
                            playedColor: Colors.red,
                            handleColor: Colors.redAccent,
                          ),
                          onEnded: (metaData) {
                            if (mounted) {
                              _controller.pause();
                            }
                          },
                        ),
                      )
                    : const Center(
                        child: CircularProgressIndicator(),
                      ),
              ),
              Positioned(
                top: 16,
                left: 16,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: _exitFullscreen,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Remove observer
    WidgetsBinding.instance.removeObserver(this);

    // Dispose controller if initialized
    if (_isControllerInitialized) {
      _controller.dispose();
    }

    // Restore orientation and system UI when leaving
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
    );

    super.dispose();
  }
}
