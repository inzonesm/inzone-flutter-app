import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerWidgetPostScreen extends StatefulWidget {
  final String videoUrl;

  VideoPlayerWidgetPostScreen(this.videoUrl);

  @override
  _VideoPlayerWidgetPostScreenState createState() => _VideoPlayerWidgetPostScreenState();
}

class _VideoPlayerWidgetPostScreenState extends State<VideoPlayerWidgetPostScreen> {
  late VideoPlayerController _controller;
  late bool _isPlaying;
  bool _showControls = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.videoUrl)
      ..initialize().then((_) {
        setState(() {
          _isLoading = false;
        });
      });

    _isPlaying = false;
    _controller.addListener(_videoListener);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _videoListener() {
    final bool isPlaying = _controller.value.isPlaying;
    if (isPlaying != _isPlaying) {
      setState(() {
        _isPlaying = isPlaying;
      });
    }
  }

  void _togglePlay() {
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }
  }

  void _toggleControlsVisibility() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    final double aspectRatio = _controller.value.aspectRatio;
    return GestureDetector(
      onTap: () {
        _togglePlay();
        _toggleControlsVisibility();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              AspectRatio(
                aspectRatio: aspectRatio,
                child: VideoPlayer(_controller),
              ),
              if (_isLoading)
                const CircularProgressIndicator(
                  color: Colors.red,
                ),
              if (_showControls)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    color: Colors.black54,
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: _togglePlay,
                          icon: Icon(
                            _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                          ),
                        ),
                        Expanded(
                          child: VideoProgressIndicator(
                            _controller,
                            allowScrubbing: true,
                            colors: VideoProgressColors(
                              playedColor: Theme.of(context).canvasColor,
                              bufferedColor: Colors.white.withOpacity(0.3),
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Padding(
                          padding: const EdgeInsets.only(top: 5.0),
                          child: Text(
                            _formatDuration(_controller.value.duration),
                            style: const TextStyle(color: Colors.white, fontSize: 10),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (!_controller.value.isPlaying && !_isPlaying && !_showControls)
                const Icon(
                  Icons.play_circle_filled,
                  size: 64,
                  color: Colors.white,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
