import 'dart:convert';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:async';

import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'package:just_audio/just_audio.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/voice_service.dart';

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
  double _speechProbability = 0.0;
  double _baseAvatarRadius = 80.0;

  late stt.SpeechToText _speech;
  bool _isSttAvailable = false;
  String _recognizedWords = "";

  bool _isProcessing = false;

  final AudioPlayer _audioPlayer = AudioPlayer();
  final EnhancedVoiceService _voiceService = EnhancedVoiceService();

  String _aiResponseText = "";
  bool _isPlayingResponse = false;
  bool _isMuted = false;
  bool _isVoiceReady = false;

  late AnimationController _processingAnimationController;
  late Animation<double> _processingAnimation;

  final ScrollController _aiScrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    // Initialize speech-to-text engine
    _speech = stt.SpeechToText();
    _initializeStt();

    // Prepare processing animation used while we wait for AI response TTS
    _processingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _processingAnimation = Tween<double>(begin: 80.0, end: 100.0).animate(
      CurvedAnimation(
          parent: _processingAnimationController, curve: Curves.easeInOut),
    );

    // Delay initial auto-start slightly so the UI can render first
    // Then auto-start listening if conditions are met
    Future.delayed(const Duration(milliseconds: 500), () {
      setState(() {
        _isVoiceReady = true;
      });
      if (mounted && !isRecording && !_isProcessing && !_isMuted) {
        _startListening();
      }
    });
  }

  void _initializeStt() async {
    _isSttAvailable = await _speech.initialize(
      onError: (error) => debugPrint('STT Error: $error'),
      onStatus: (status) => debugPrint('STT Status: $status'),
    );
    debugPrint('STT Available: $_isSttAvailable');
    if (mounted) setState(() {});
  }

  void _startListening() async {
    debugPrint(
        '_startListening called - STT Available: $_isSttAvailable, Recording: $isRecording, Processing: $_isProcessing, Muted: $_isMuted');

    if (!_isSttAvailable ||
        isRecording ||
        _isProcessing ||
        _isMuted ||
        _isPlayingResponse) {
      return;
    }

    if (mounted) {
      setState(() {
        _recognizedWords = "";
        _aiResponseText = "";
      });
    }

    try {
      debugPrint('Starting speech.listen...');
      await _speech.listen(
        // Called continuously with partial and final transcriptions
        onResult: (result) {
          debugPrint(
              'Speech result: ${result.recognizedWords}, final: ${result.finalResult}');
          if (!mounted) return;
          setState(() => _recognizedWords = result.recognizedWords);
          // Stop as soon as the engine marks the result as final
          if (result.finalResult) {
            _stopListening();
          }
        },
        localeId: 'en_US',
        // Maximum session duration before auto-stopping
        listenFor: const Duration(minutes: 3),
        // Silence timeout: stop if no speech is detected for this duration
        // Note: currently 2000ms (2 seconds). Increase to allow longer pauses.
        pauseFor: const Duration(milliseconds: 2000),
        cancelOnError: true,
        partialResults: true,
        // Confirmation mode is optimized for discrete utterances
        listenMode: stt.ListenMode.confirmation,
        // Track input sound level to drive UI animation
        onSoundLevelChange: (level) {
          if (!mounted) return;
          final normalizedLevel = (level + 120) / 120;
          setState(() {
            _speechProbability = normalizedLevel.clamp(0.0, 1.0);
          });
        },
      );
      debugPrint('Speech listening started successfully');
      if (mounted) {
        setState(() {
          isRecording = true;
          _baseAvatarRadius = 60.0;
        });
      }
    } catch (e) {
      debugPrint('Failed to start speech listening: $e');
    }
  }

  /// Stop the current STT session.
  /// If [shouldProcess] is true and we have transcribed text, we will
  /// send it to the backend and await the AI TTS response.
  void _stopListening({bool shouldProcess = true}) async {
    if (!isRecording) return;

    try {
      await _speech.stop();
    } catch (_) {}

    final hasSpeech = _recognizedWords.trim().isNotEmpty;

    if (mounted) {
      setState(() {
        isRecording = false;
        if (shouldProcess && hasSpeech) {
          // Enter processing state while waiting for server + TTS
          _isProcessing = true;
          _processingAnimationController.repeat(reverse: true);
        }
        _baseAvatarRadius = 80.0;
        _speechProbability = 0.0;
      });
    }

    if (shouldProcess && hasSpeech) {
      await _sendTextToBackend();
    } else {
      if (!hasSpeech && !_isMuted && mounted) {
        // Slight delay before attempting to re-start listening
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && !isRecording && !_isProcessing && !_isMuted) {
            _startListening();
          }
        });
      }
    }
  }

  Future<void> _sendTextToBackend() async {
    try {
      if (_recognizedWords.trim().isEmpty) return;

      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      // Orchestrates chat completion and TTS generation
      final result = await _voiceService.sendTextForVoice(
        userId: userId,
        aiCharacterId: widget.avatarId,
        message: _recognizedWords,
        chatHistory: null,
      );

      if (!mounted) return;

      setState(() {
        _isProcessing = false;
      });
      _processingAnimationController.stop();
      _processingAnimationController.reset();

      if (result.response != null) {
        final r = result.response!;
        setState(() {
          _recognizedWords = r.userSpeechText;
          _aiResponseText = r.aiResponseText;
        });

        // Play the AI TTS audio and then optionally re-arm listening
        await _playAIResponse(r.aiResponseAudio);
      } else if (result.error != null) {
        final e = result.error!;
        setState(() {
          _recognizedWords = "❌ ${e.message}";
          _aiResponseText = e.requiredCoins > 0
              ? "You need ${e.requiredCoins} coins but only have ${e.currentBalance}."
              : "Request failed: ${e.message}";
        });
      } else {
        setState(() {
          _recognizedWords = "Failed to process voice message";
        });
      }
    } catch (e) {
      debugPrint('Error in _sendTextToBackend: $e');
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _recognizedWords = "Error processing voice message";
      });
      _processingAnimationController.stop();
      _processingAnimationController.reset();
    }
  }

  /// Play AI TTS audio from base64-encoded MPEG data.
  /// When playback finishes, re-start listening if not muted or busy.
  Future<void> _playAIResponse(String base64Audio) async {
    if (base64Audio.isEmpty) return;

    try {
      setState(() => _isPlayingResponse = true);

      final audioData = base64Decode(base64Audio);

      await _audioPlayer.stop();

      final audioSource = _MyCustomSource(audioData);

      await _audioPlayer.setAudioSource(audioSource);
      await _audioPlayer.play();

      await _audioPlayer.playerStateStream.firstWhere(
        (state) => state.processingState == ProcessingState.completed,
      );

      if (mounted) {
        setState(() => _isPlayingResponse = false);
      }

      if (!_isMuted && mounted) {
        // After TTS completes, small delay then re-arm listening
        debugPrint('AI response completed, restarting listening...');
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted &&
            !isRecording &&
            !_isProcessing &&
            !_isMuted &&
            !_isPlayingResponse) {
          _startListening();
        }
      }
    } catch (e) {
      debugPrint('Error playing AI response: $e');

      if (mounted) {
        setState(() => _isPlayingResponse = false);
      }

      if (!_isMuted && mounted) {
        // If playback failed, try to re-arm listening after a brief delay
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted && !isRecording && !_isProcessing && !_isMuted) {
          _startListening();
        }
      }
    }
  }

  @override
  void dispose() {
    // Stop STT, audio, and animations; clean up controllers
    _speech.stop();
    _audioPlayer.dispose();
    _processingAnimationController.dispose();
    _aiScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).canvasColor,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                const SizedBox(height: 50),
                const Spacer(),
                _isProcessing
                    ? AnimatedBuilder(
                        animation: _processingAnimation,
                        builder: (context, child) {
                          return CircleAvatar(
                            radius: _processingAnimation.value,
                            backgroundColor: Colors.transparent,
                            backgroundImage: widget.avatarUrl.isNotEmpty
                                ? NetworkImage(widget.avatarUrl)
                                : null,
                          );
                        },
                      )
                    : TweenAnimationBuilder<double>(
                        tween: Tween<double>(
                            begin: _baseAvatarRadius,
                            end: _baseAvatarRadius +
                                (_speechProbability * 40.0)),
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
                const SizedBox(height: 20),
                if (_recognizedWords.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    constraints: const BoxConstraints(maxHeight: 100),
                    child: SingleChildScrollView(
                      child: Text(
                        _recognizedWords,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.6),
                          letterSpacing: 0.1,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Expanded(
                  flex: 3,
                  child: SingleChildScrollView(
                    controller: _aiScrollController,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isProcessing)
                          Shimmer.fromColors(
                            baseColor: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.4),
                            highlightColor: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.8),
                            period: const Duration(milliseconds: 1500),
                            child: const Text(
                              "Thinking...",
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.2),
                            ),
                          )
                        else if (_aiResponseText.isNotEmpty && !_isProcessing)
                          Column(
                            children: [
                              AnimatedTextKit(
                                key: ValueKey('ai_$_aiResponseText'),
                                animatedTexts: [
                                  TypewriterAnimatedText(
                                    _aiResponseText,
                                    textAlign: TextAlign.center,
                                    textStyle: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                      height: 1.5,
                                      letterSpacing: -0.3,
                                    ),
                                    speed: const Duration(milliseconds: 40),
                                  ),
                                ],
                                totalRepeatCount: 1,
                                displayFullTextOnTap: true,
                                isRepeatingAnimation: false,
                              ),
                              if (_isPlayingResponse)
                                Padding(
                                  padding: const EdgeInsets.only(top: 20),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.volume_up_rounded,
                                          size: 18,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withOpacity(0.6)),
                                      const SizedBox(width: 6),
                                      Text("Speaking",
                                          style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withOpacity(0.6))),
                                    ],
                                  ),
                                ),
                            ],
                          )
                        else if (isRecording)
                          Column(
                            children: [
                              Shimmer.fromColors(
                                baseColor: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.6),
                                highlightColor:
                                    Theme.of(context).colorScheme.onSurface,
                                period: const Duration(milliseconds: 1200),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.mic,
                                        size: 20,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface),
                                    const SizedBox(width: 8),
                                    const Text("Listening",
                                        style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: -0.3)),
                                  ],
                                ),
                              ),
                            ],
                          )
                        else
                          AnimatedOpacity(
                            opacity: 0.5,
                            duration: const Duration(milliseconds: 500),
                            child: Text(
                              "Say something...",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.3),
                                letterSpacing: -0.3,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () async {
                          if (_isPlayingResponse || _isProcessing) {
                            return;
                          }

                          if (isRecording) {
                            _stopListening();
                          } else {
                            if (_isMuted) {
                              setState(() => _isMuted = false);
                              await Future.delayed(
                                  const Duration(milliseconds: 100));
                            }
                            _startListening();
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: (_isProcessing || _isPlayingResponse)
                                ? LinearGradient(colors: [
                                    Colors.grey.shade600,
                                    Colors.grey.shade500
                                  ])
                                : isRecording
                                    ? LinearGradient(colors: [
                                        Colors.red.shade600,
                                        Colors.red.shade500
                                      ])
                                    : LinearGradient(colors: [
                                        Theme.of(context).colorScheme.primary,
                                        Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withOpacity(0.8),
                                      ]),
                            boxShadow: [
                              BoxShadow(
                                color: (_isProcessing || _isPlayingResponse)
                                    ? Colors.grey.withOpacity(0.3)
                                    : isRecording
                                        ? Colors.red.withOpacity(0.4)
                                        : Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withOpacity(0.4),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Icon(
                            (_isProcessing || _isPlayingResponse)
                                ? Icons.mic_off
                                : isRecording
                                    ? Icons.stop_rounded
                                    : _isMuted
                                        ? FeatherIcons.micOff
                                        : FeatherIcons.mic,
                            size: 30,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 40),
                      GestureDetector(
                        onTap: () {
                          if (isRecording) _stopListening();
                          _audioPlayer.stop();
                          context.pop();
                        },
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey.shade800.withOpacity(0.5)
                                    : Colors.grey.shade300.withOpacity(0.5),
                          ),
                          child: Icon(
                            FeatherIcons.x,
                            size: 30,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (!_isVoiceReady)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.7),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (widget.avatarUrl.isNotEmpty)
                          TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0.8, end: 1.2),
                            duration: const Duration(milliseconds: 1000),
                            builder: (context, scale, child) {
                              return Transform.scale(
                                scale: scale,
                                child: CircleAvatar(
                                  radius: 60,
                                  backgroundColor: Colors.transparent,
                                  backgroundImage:
                                      NetworkImage(widget.avatarUrl),
                                ),
                              );
                            },
                            onEnd: () {
                              if (!_isVoiceReady && mounted) {
                                setState(() {});
                              }
                            },
                          ),
                        const SizedBox(height: 30),
                        const CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          "Preparing voice...",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "This may take a few seconds",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MyCustomSource extends StreamAudioSource {
  final List<int> bytes;

  _MyCustomSource(this.bytes);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= bytes.length;
    return StreamAudioResponse(
      sourceLength: bytes.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(bytes.sublist(start, end)),
      contentType: 'audio/mpeg',
    );
  }
}
