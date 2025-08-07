import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'package:vad/vad.dart';

class VoiceScreen extends StatefulWidget {
  final String avatarUrl;
  final String avatarId;
  const VoiceScreen({super.key, this.avatarUrl = "", this.avatarId = ""});

  @override
  _VoiceScreenState createState() => _VoiceScreenState();
}

class _VoiceScreenState extends State<VoiceScreen>
    with TickerProviderStateMixin {
  bool isRecording = false;
  dynamic _vadHandler;
  StreamSubscription? _frameSubscription;
  double _speechProbability = 0.0;
  double _baseAvatarRadius = 80.0;

  @override
  void initState() {
    super.initState();
    _vadHandler = VadHandler.create(isDebug: true);

    _vadHandler.onSpeechEnd.listen((List<double> samples) {
      // You can process the audio samples here if needed
    });

    _frameSubscription = _vadHandler.onFrameProcessed.listen((frameData) {
      if (mounted && isRecording) {
        setState(() {
          _speechProbability = frameData.isSpeech;
        });
      }
    });
  }

  @override
  void dispose() {
    _frameSubscription?.cancel();
    _vadHandler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).canvasColor,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 12.0, top: 6.0),
                child: GestureDetector(
                  onTap: () {
                    context.pop();
                  },
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor:
                        Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey.shade800
                            : Colors.grey.shade200,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Center(
                        child: Icon(
                          Icons.arrow_back_ios,
                          size: 18,
                          color: Theme.of(context).iconTheme.color,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const Spacer(),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(
                  begin: _baseAvatarRadius,
                  end: _baseAvatarRadius + (_speechProbability * 40.0)),
              duration: const Duration(milliseconds: 150),
              curve: Curves.fastOutSlowIn,
              builder: (context, radius, child) {
                return CircleAvatar(
                  radius: radius,
                  backgroundImage: NetworkImage(widget.avatarUrl),
                );
              },
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 40.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () async {
                      if (isRecording) {
                        await _vadHandler.stopListening();
                      } else {
                        await _vadHandler.startListening();
                      }
                      if (mounted) {
                        setState(() {
                          isRecording = !isRecording;
                          if (isRecording) {
                            _baseAvatarRadius = 60.0;
                          } else {
                            _baseAvatarRadius = 80.0;
                            _speechProbability = 0.0;
                          }
                        });
                      }
                    },
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isRecording
                            ? Colors.red
                            : Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey.shade800
                                : Colors.white,
                      ),
                      child: Icon(
                        isRecording ? Icons.stop : Icons.mic,
                        size: 40,
                        color: isRecording
                            ? Colors.white
                            : Theme.of(context).iconTheme.color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
