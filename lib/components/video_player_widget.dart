import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;

  const VideoPlayerWidget({Key? key, required this.videoUrl}) : super(key: key);

  @override
  _VideoPlayerWidgetState createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _videoPlayerController;
  bool _isPlaying = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _videoPlayerController = VideoPlayerController.network(widget.videoUrl)
      ..initialize().then((_) {
        setState(() {
          _isInitialized = true;
        });
      });
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _isPlaying
        ? AspectRatio(
      aspectRatio: _videoPlayerController.value.aspectRatio,
      child: VideoPlayer(_videoPlayerController),
    )
        : GestureDetector(
      onTap: () {
        setState(() {
          _isPlaying = true;
        });
        _videoPlayerController.play();
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Show the first frame as the thumbnail if video is initialized
          _isInitialized
              ? AspectRatio(
            aspectRatio: _videoPlayerController.value.aspectRatio,
            child: VideoPlayer(_videoPlayerController),
          )
              : Container(
            color: Colors.black, // A simple background color
            width: MediaQuery.of(context).size.width - 60,
            child: const Center(
              child: Icon(
                Icons.play_circle_outline,
                color: Colors.white,
                size: 60,
              ),
            ),
          ),

           const Icon(
            Icons.play_circle_outline,
            color: Colors.white,
            size: 60,
          ),
        ],
      ),
    );
  }
}
