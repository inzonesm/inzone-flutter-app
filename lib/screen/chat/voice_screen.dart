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

import '../../services/voice_service_v2.dart';

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
  bool _isVoiceReady = false; // Voice 준비 상태 추가

  late AnimationController _processingAnimationController;
  late Animation<double> _processingAnimation;

  final ScrollController _aiScrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    _speech = stt.SpeechToText();
    _initializeStt();

    _processingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _processingAnimation = Tween<double>(begin: 80.0, end: 100.0).animate(
      CurvedAnimation(
          parent: _processingAnimationController, curve: Curves.easeInOut),
    );

    // 페이지 진입 시 자동으로 리스닝 시작
    Future.delayed(const Duration(milliseconds: 500), () {
      setState(() {
        _isVoiceReady = true; // 바로 준비 완료로 설정
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
        _isPlayingResponse) return;

    if (mounted) {
      setState(() {
        _recognizedWords = "";
        _aiResponseText = "";
      });
    }

    try {
      debugPrint('Starting speech.listen...');
      await _speech.listen(
        onResult: (result) {
          debugPrint(
              'Speech result: ${result.recognizedWords}, final: ${result.finalResult}');
          if (!mounted) return;
          setState(() => _recognizedWords = result.recognizedWords);
          if (result.finalResult) {
            _stopListening();
          }
        },
        localeId: 'en_US',
        listenFor: const Duration(minutes: 3),
        pauseFor: const Duration(milliseconds: 1500),
        cancelOnError: true,
        partialResults: true,
        listenMode: stt.ListenMode.confirmation,
        onSoundLevelChange: (level) {
          if (!mounted) return;
          // level은 보통 -120에서 0 사이의 dB 값입니다.
          // 이를 0.0에서 1.0 사이로 정규화하여 UI에 사용합니다.
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
      // 음성이 없었으면 자동으로 다시 리스닝 시작
      if (!hasSpeech && !_isMuted && mounted) {
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

      final result = await _voiceService.sendTextForVoice(
        userId: userId,
        aiCharacterId: widget.avatarId,
        message: _recognizedWords,
        chatHistory: null, // 백엔드가 처리하도록 null 전달
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

        // Voice response received successfully

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

      // AI 응답 재생이 끝나면 _playAIResponse에서 자동으로 리스닝을 시작하므로 여기서는 시작하지 않음
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

  Future<void> _playAIResponse(String base64Audio) async {
    if (base64Audio.isEmpty) return;

    try {
      setState(() => _isPlayingResponse = true);

      // Decode audio
      final audioData = base64Decode(base64Audio);

      // Stop any currently playing audio
      await _audioPlayer.stop();

      // Create a custom AudioSource
      final audioSource = _MyCustomSource(audioData);

      // Set source and play
      await _audioPlayer.setAudioSource(audioSource);
      await _audioPlayer.play();

      // Wait for completion
      await _audioPlayer.playerStateStream.firstWhere(
        (state) => state.processingState == ProcessingState.completed,
      );

      // Playback completed
      if (mounted) {
        setState(() => _isPlayingResponse = false);
      }

      // Start listening again after AI response
      if (!_isMuted && mounted) {
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

      // Try to restart listening even on error
      if (!_isMuted && mounted) {
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted && !isRecording && !_isProcessing && !_isMuted) {
          _startListening();
        }
      }
    }
  }

  @override
  void dispose() {
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
                          // AI가 말하는 중에는 아무 동작도 하지 않음
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
            // 로딩 오버레이
            if (!_isVoiceReady)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.7),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 아바타 이미지를 로딩 중에도 표시
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
                              // 애니메이션 반복을 위해 rebuild
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
