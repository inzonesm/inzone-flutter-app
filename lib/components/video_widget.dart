import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:ffmpeg_kit_flutter/ffprobe_kit.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:flutter/rendering.dart';



bool _isYoutubeFullscreenActive = false;

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
      _youtubePlayerController = YoutubePlayerController(
        initialVideoId: _youtubeVideoId!,
        flags: const YoutubePlayerFlags(
          autoPlay: false,
          mute: false,
          enableCaption: true,
          hideControls: false,
          forceHD: true,
        ),
      );
      
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
    final codec = await analyzeVideo(widget.videoUrl);

    if (codec == null) {
      setState(() {
        _isPlayable = false;
        _isLoading = false;
      });
      return;
    }

    if (codec == 'vp9') {
      _useMediaKit = true;
      await _initializeMediaKitPlayer(widget.videoUrl);
    } else {
      await _initializeVideoPlayer(widget.videoUrl);
    }
  }

  Future<String?> analyzeVideo(String videoPath) async {
    try {
      final session = await FFprobeKit.getMediaInformation(videoPath);
      final info = session.getMediaInformation();

      if (info != null) {
        final streams = info.getStreams();
        for (var stream in streams) {
          if (stream.getType() == 'video') {
            return stream.getCodec();
          }
        }
            }
    } catch (e) {
      print('FFprobe error: $e');
    }
    return null;
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
      
      // Store the current position before navigating
      final Duration currentPosition = _youtubePlayerController!.value.position;
      
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => FullscreenYoutubePlayer(
            videoId: _youtubeVideoId!,
            startAt: currentPosition,
          ),
        ),
      ).then((_) {
        // Reset the flag when returning from fullscreen
        _isYoutubeFullscreenActive = false;
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
    aspectRatio = defaultWidth / defaultHeight; // Final fallback in case both are null

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
            if (info.visibleFraction == 0 && _youtubePlayerController!.value.isPlaying) {
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
        
        if (info.visibleFraction == 0) {
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
    if (_youtubePlayerController != null) {
      _youtubePlayerController!.pause();
      _youtubePlayerController!.dispose();
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
  _FullscreenYoutubePlayerState createState() => _FullscreenYoutubePlayerState();
}

class _FullscreenYoutubePlayerState extends State<FullscreenYoutubePlayer> with WidgetsBindingObserver {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    
    // Add observer for lifecycle events
    WidgetsBinding.instance.addObserver(this);
    
    // Lock the orientation to landscape
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    // Hide status bar
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
    );
    
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
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Ensure orientation is locked to landscape when app is resumed
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  void _exitFullscreen() async {
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
              Center(
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
    
    // Restore orientation and system UI when leaving
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
    );
    _controller.dispose();
    super.dispose();
  }
}