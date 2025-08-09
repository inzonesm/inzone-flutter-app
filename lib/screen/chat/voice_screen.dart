import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'package:vad/vad.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

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

  late stt.SpeechToText _speech;
  bool _isSttAvailable = false;
  String _recognizedWords = "";
  Timer? _stopTimer;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initializeStt();
    _vadHandler = VadHandler.create(isDebug: true);

    _frameSubscription = _vadHandler.onFrameProcessed.listen((frameData) {
      if (mounted && isRecording) {
        setState(() {
          _speechProbability = frameData.isSpeech;
        });
      }
    });

    // VAD gives us hints about speech activity to manage the timer
    _vadHandler.onSpeechStart.listen((_) {
      _resetStopTimer();
    });

    _vadHandler.onSpeechEnd.listen((_) {
      _startStopTimer();
    });
  }

  void _initializeStt() async {
    _isSttAvailable = await _speech.initialize();
    if (mounted) {
      setState(() {});
    }
  }

  void _startStopTimer() {
    _stopTimer?.cancel();
    _stopTimer = Timer(const Duration(seconds: 2), () {
      if (isRecording) {
        debugPrint("Silence detected for 2 seconds. Stopping automatically.");
        _stopListening();
      }
    });
  }

  void _resetStopTimer() {
    _stopTimer?.cancel();
  }

  void _startListening() async {
    if (!_isSttAvailable || isRecording) return;

    _resetStopTimer();
    await _vadHandler.startListening();

    _speech.listen(
      onResult: (result) {
        if (mounted) {
          _resetStopTimer();
          setState(() {
            _recognizedWords = result.recognizedWords;
          });
          if (result.finalResult) {
            _startStopTimer();
          }
        }
      },
      localeId: 'en_US',
      listenFor: const Duration(minutes: 3),
    );

    if (mounted) {
      setState(() {
        isRecording = true;
        _baseAvatarRadius = 60.0;
        _recognizedWords = "";
      });
    }
  }

  void _stopListening() {
    if (!isRecording) return;

    _resetStopTimer();
    _vadHandler.stopListening();
    _speech.stop();

    if (mounted) {
      setState(() {
        isRecording = false;
        _recognizedWords = "";
        _baseAvatarRadius = 80.0;
        _speechProbability = 0.0;
      });
    }
  }

  @override
  void dispose() {
    _stopTimer?.cancel();
    _frameSubscription?.cancel();
    _vadHandler.dispose();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).canvasColor,
      body: SafeArea(
        child: Column(
          children: [
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
                  backgroundColor: Colors.transparent,
                  backgroundImage: widget.avatarUrl.isNotEmpty
                      ? NetworkImage(widget.avatarUrl)
                      : null,
                );
              },
            ),
            const Spacer(),
            Container(
              constraints: const BoxConstraints(minHeight: 60),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              alignment: Alignment.center,
              child: _recognizedWords.isNotEmpty
                  ? AnimatedTextKit(
                      key: ValueKey(_recognizedWords),
                      animatedTexts: [
                        RotateAnimatedText(
                          _recognizedWords,
                          textAlign: TextAlign.center,
                          textStyle:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w600,
                                  ),
                          duration: const Duration(milliseconds: 400),
                          rotateOut: false,
                        ),
                      ],
                      totalRepeatCount: 1,
                    )
                  : Text(
                      "...",
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 40.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () {
                      if (isRecording) {
                        _stopListening();
                      } else {
                        _startListening();
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
                        isRecording ? Icons.stop : FeatherIcons.phone,
                        size: 40,
                        color: isRecording ? Colors.white : Colors.blueAccent,
                      ),
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SizeTransition(
                          axis: Axis.horizontal,
                          sizeFactor: animation,
                          child: child,
                        ),
                      );
                    },
                    child: !isRecording
                        ? Row(
                            key: const ValueKey('show_exit'),
                            children: [
                              const SizedBox(width: 20),
                              GestureDetector(
                                onTap: () {
                                  context.pop();
                                },
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.grey.shade800
                                        : Colors.white,
                                  ),
                                  child: Icon(
                                    FeatherIcons.x,
                                    size: 40,
                                    color: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.grey.shade400
                                        : Colors.red.shade600,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : const SizedBox(key: ValueKey('hide_exit')),
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
