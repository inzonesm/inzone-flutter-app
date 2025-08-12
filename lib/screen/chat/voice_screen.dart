import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:vad/vad.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/enhanced_voice_service.dart';

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

  // Audio recording
  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _audioPath;
  bool _isProcessing = false;

  // Audio playback
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Voice service
  final EnhancedVoiceService _voiceService = EnhancedVoiceService();

  // AI response
  String _aiResponseText = "";
  bool _isPlayingResponse = false;

  // Mute state
  bool _isMuted = false; // Auto-listen on enter

  // Animation for processing
  late AnimationController _processingAnimationController;
  late Animation<double> _processingAnimation;

  // Scroll controller for AI responses
  final ScrollController _aiScrollController = ScrollController();

  // Helper: auto-start listening when ready
  void _maybeAutoStartListening() {
    if (!_isMuted && !isRecording && !_isProcessing && _isSttAvailable) {
      _startListening();
    }
  }

  @override
  void initState() {
    super.initState();

    // Print received IDs
    print("=== VoiceScreen initState ===");
    print("Received avatarUrl: ${widget.avatarUrl}");
    print("Received avatarId: ${widget.avatarId}");
    print("Is avatarId empty?: ${widget.avatarId.isEmpty}");
    print("============================");

    _speech = stt.SpeechToText();
    _initializeStt();
    _vadHandler = VadHandler.create(isDebug: true);

    // Initialize processing animation
    _processingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _processingAnimation = Tween<double>(
      begin: 80.0,
      end: 100.0,
    ).animate(CurvedAnimation(
      parent: _processingAnimationController,
      curve: Curves.easeInOut,
    ));

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

    // Auto-start listening on init (after first frame)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _maybeAutoStartListening();
      }
    });
  }

  void _initializeStt() async {
    final available = await _speech.initialize();
    if (mounted) {
      setState(() {
        _isSttAvailable = available;
      });
      // If user expects immediate listening, start as soon as STT becomes available
      _maybeAutoStartListening();
    }
  }

  void _startStopTimer() {
    _stopTimer?.cancel();
    _stopTimer = Timer(const Duration(milliseconds: 600), () {
      if (isRecording) {
        // If no speech for timeout, stop and process if we have text, otherwise restart listening
        final hasSpeech = _recognizedWords.trim().isNotEmpty;
        print(
            "Silence detected, hasSpeech=$hasSpeech -> ${hasSpeech ? 'process' : 'restart'}");
        _stopListening(shouldProcess: hasSpeech);
        if (!hasSpeech && !_isMuted) {
          // Restart listening immediately for continuous mode
          if (mounted && !isRecording && !_isProcessing) {
            _startListening();
          }
        }
      }
    });
  }

  void _resetStopTimer() {
    _stopTimer?.cancel();
  }

  void _startListening() async {
    if (!_isSttAvailable || isRecording || _isProcessing || _isMuted) return;

    // If AI audio is playing, stop it synchronously before starting mic
    if (_isPlayingResponse) {
      try {
        await _audioPlayer.stop();
      } catch (_) {}
      if (mounted) {
        setState(() {
          _isPlayingResponse = false;
        });
      }
    }

    _resetStopTimer();

    // Start audio recording
    try {
      final directory = await getTemporaryDirectory();
      _audioPath =
          '${directory.path}/recording_${DateTime.now().millisecondsSinceEpoch}.wav';

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          bitRate: 16000,
        ),
        path: _audioPath!,
      );

      print('Audio recording started: $_audioPath');
    } catch (e) {
      print('Error starting audio recording: $e');
      return;
    }

    try {
      await _vadHandler.startListening();
    } catch (_) {}

    // Ensure STT is ready; if not, initialize then try again
    if (!_isSttAvailable) {
      _initializeStt();
      if (!_isSttAvailable) return;
    }

    await _speech.listen(
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
        // Don't clear AI response text to maintain conversation context
      });
    }
  }

  void _stopListening({bool shouldProcess = true}) async {
    if (!isRecording) return;

    _resetStopTimer();
    _vadHandler.stopListening();
    _speech.stop();

    // Don't stop AI response anymore - volume is already lowered in _playAIResponse
    // This allows AI to continue in background at low volume

    // Stop audio recording
    try {
      await _audioRecorder.stop();
      print('Audio recording stopped: $_audioPath');
    } catch (e) {
      print('Error stopping audio recording: $e');
    }

    // Check if we actually have meaningful speech to process
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

    // Send audio to API only if we should process AND have actual speech
    if (_audioPath != null && shouldProcess && hasSpeech) {
      await _sendVoiceToAPI();
    } else if (_audioPath != null) {
      // Clean up audio file if we're not processing or no speech detected
      try {
        final audioFile = File(_audioPath!);
        if (audioFile.existsSync()) {
          await audioFile.delete();
        }
        _audioPath = null;
      } catch (e) {
        print('Error deleting audio file: $e');
      }

      // If no speech detected, restart listening
      if (shouldProcess && !hasSpeech && !_isMuted) {
        print('No speech detected, restarting listening immediately...');
        if (mounted && !isRecording && !_isProcessing && !_isMuted) {
          _startListening();
        }
      }
    }
  }

  Future<void> _sendVoiceToAPI() async {
    if (_audioPath == null) return;

    try {
      // Check if we have recognized text
      if (_recognizedWords.trim().isEmpty) {
        print('No speech recognized, skipping API call');
        return;
      }

      print('Sending text to API for voice response...');
      print('Recognized text: $_recognizedWords');

      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        print("User not logged in");
        // Handle not logged in case
        return;
      }

      final aiCharacterId = widget.avatarId;
      print("Using avatarId: $aiCharacterId");

      // Use the enhanced voice service with direct Firebase integration
      final result = await _voiceService.sendTextForVoice(
        userId: userId,
        aiCharacterId: aiCharacterId,
        message: _recognizedWords,
        chatHistory: null, // You can add chat history if needed
      );

      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        _processingAnimationController.stop();
        _processingAnimationController.reset();

        if (result.response != null) {
          final response = result.response!;

          // 성공한 API 응답 상세 출력
          print('========== 성공한 API 응답 ==========');
          print('User Speech Text: ${response.userSpeechText}');
          print('AI Response Text: ${response.aiResponseText}');
          print('Conversation ID: ${response.conversationId}');
          print('Coins Deducted: ${response.coinsDeducted}');
          print('Remaining Balance: ${response.remainingBalance}');
          print('Audio Data Length: ${response.aiResponseAudio.length} chars');
          print('=====================================');

          if (mounted) {
            setState(() {
              _recognizedWords = response.userSpeechText;
              _aiResponseText = response.aiResponseText;
            });

            // Auto-scroll to bottom when AI response is received
            Future.delayed(const Duration(milliseconds: 100), () {
              if (_aiScrollController.hasClients) {
                _aiScrollController.animateTo(
                  _aiScrollController.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOut,
                );
              }
            });
          }

          // Play AI response audio
          await _playAIResponse(response.aiResponseAudio);
        } else if (result.error != null) {
          final error = result.error!;
          print('API Error: ${error.message}');
          if (mounted) {
            setState(() {
              _recognizedWords = "❌ ${error.message}";
              _aiResponseText =
                  "You need ${error.requiredCoins} coins but only have ${error.currentBalance} coins. Please purchase more coins to continue.";
            });
          }
        } else {
          print('Failed to get response from API');
          if (mounted) {
            setState(() {
              _recognizedWords = "Failed to process voice message";
            });
          }
        }
      }

      // Clean up audio file (even though we didn't send it)
      try {
        final audioFile = File(_audioPath!);
        if (audioFile.existsSync()) {
          await audioFile.delete();
          print('Audio file deleted: $_audioPath');
        }
      } catch (e) {
        print('Error deleting audio file: $e');
      }
    } catch (e) {
      print('Error sending voice to API: $e');
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _recognizedWords = "Error processing voice message";
        });
        _processingAnimationController.stop();
        _processingAnimationController.reset();
      }
    }
  }

  Future<void> _playAIResponse(String base64Audio) async {
    if (base64Audio.isEmpty) return;

    try {
      setState(() {
        _isPlayingResponse = true;
      });

      // Decode base64 audio and save to temporary file
      final audioData = base64Decode(base64Audio);
      final directory = await getTemporaryDirectory();
      final audioPath =
          '${directory.path}/ai_response_${DateTime.now().millisecondsSinceEpoch}.mp3';
      final audioFile = File(audioPath);
      await audioFile.writeAsBytes(audioData);

      // Play the audio
      await _audioPlayer.setFilePath(audioPath);
      await _audioPlayer.play();

      // Do NOT start listening automatically while AI is speaking.
      // We will only start listening immediately after interrupt or after playback completes.

      // Monitor speech detection to pause AI if user speaks (we rely on interrupt button to fully stop)
      StreamSubscription? speechDetectionSub;
      speechDetectionSub = _vadHandler.onSpeechStart.listen((_) {
        if (_isPlayingResponse) {
          print('User started speaking - pausing AI playback');
          _audioPlayer.pause();
        }
      });

      // Wait for playback to finish
      _audioPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed ||
            state.processingState == ProcessingState.idle) {
          if (mounted) {
            setState(() {
              _isPlayingResponse = false;
            });
            speechDetectionSub?.cancel();

            // Auto-start listening immediately after AI finishes speaking
            if (!_isMuted && !isRecording && !_isProcessing) {
              _startListening();
            }
          }
          // Clean up audio file
          audioFile.delete().catchError((e) {
            print('Error deleting AI response audio file: $e');
            return audioFile;
          });
        }
      });
    } catch (e) {
      print('Error playing AI response: $e');
      if (mounted) {
        setState(() {
          _isPlayingResponse = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _stopTimer?.cancel();
    _frameSubscription?.cancel();
    _vadHandler.dispose();
    _speech.stop();
    _audioRecorder.dispose();
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
        child: Column(
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
            const SizedBox(height: 20),

            // User text area (fixed position, always visible)
            if (_recognizedWords.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  _recognizedWords,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.3),
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Response area (scrollable, larger)
            Expanded(
              flex: 3,
              child: SingleChildScrollView(
                controller: _aiScrollController,
                physics: const BouncingScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // iOS-style unified text display
                    if (_isProcessing)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          children: [
                            // Processing animation with shimmer
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
                                  fontSize: 18, // Reduced from 24
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (_aiResponseText.isNotEmpty && !_isProcessing)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Column(
                          children: [
                            // Response with animated text that stays visible
                            AnimatedTextKit(
                              key: ValueKey('ai_$_aiResponseText'),
                              animatedTexts: [
                                TypewriterAnimatedText(
                                  _aiResponseText,
                                  textAlign: TextAlign.center,
                                  textStyle: TextStyle(
                                    fontSize: 18, // Reduced from 26
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface, // Changed from primary to onSurface
                                    height: 1.5,
                                    letterSpacing: -0.3,
                                  ),
                                  speed: const Duration(milliseconds: 40),
                                ),
                              ],
                              totalRepeatCount: 1,
                              displayFullTextOnTap: true,
                              isRepeatingAnimation:
                                  false, // Keep text visible after animation
                              onFinished: () {
                                // Keep text visible after animation finishes
                              },
                            ),
                            // Playing indicator
                            if (_isPlayingResponse) ...[
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.volume_up_rounded,
                                    size: 18,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.6),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Speaking",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withOpacity(0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      )
                    else if (isRecording)
                      Column(
                        children: [
                          // Shimmer effect for listening state
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
                                Icon(
                                  Icons.mic,
                                  size: 20,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  "Listening",
                                  style: TextStyle(
                                    fontSize: 18, // Reduced from 26
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Animated dots indicator
                          SizedBox(
                            height: 10,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(3, (index) {
                                return AnimatedContainer(
                                  duration: Duration(
                                      milliseconds: 300 + (index * 100)),
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 3),
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(_speechProbability > 0.3
                                            ? 0.7
                                            : 0.3),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ],
                      )
                    else if (!_isSttAvailable)
                      Column(
                        children: [
                          Icon(
                            Icons.mic_none_rounded,
                            size: 32,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.3),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "Tap to start",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.4),
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      )
                    else
                      // Default state when ready
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
                      // Toggle mute
                      final nextMuted = !_isMuted;
                      setState(() {
                        _isMuted = nextMuted;
                      });

                      if (nextMuted) {
                        // Muting: stop listening immediately, don't process
                        if (isRecording) {
                          _stopListening(shouldProcess: false);
                        }
                        _audioPlayer.stop();
                        return;
                      }

                      // Unmuting: start listening immediately (no delay)
                      if (!isRecording && !_isProcessing) {
                        _startListening();
                      }
                    },
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isMuted
                            ? Colors.redAccent
                            : Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey.shade800
                                : Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.2),
                      ),
                      child: Icon(
                          _isMuted ? FeatherIcons.micOff : FeatherIcons.mic,
                          size: 22,
                          color: _isMuted ? Colors.white : Colors.white),
                    ),
                  ),
                  const SizedBox(width: 20),
                  // Interrupt button (always visible, disabled when AI is not speaking)
                  GestureDetector(
                    onTap: _isPlayingResponse
                        ? () async {
                            // Ensure AI playback fully stops first
                            try {
                              await _audioPlayer.stop();
                            } catch (_) {}
                            if (mounted) {
                              setState(() {
                                _isPlayingResponse = false;
                              });
                            }
                            // Immediately start listening with no delay
                            if (!_isMuted && !isRecording && !_isProcessing) {
                              _startListening();
                            }
                          }
                        : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isPlayingResponse
                            ? Colors.orange.shade600
                            : Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey.shade800
                                : Colors.grey.shade300,
                      ),
                      child: Icon(
                        Icons.stop_circle,
                        size: 28,
                        color: _isPlayingResponse
                            ? Colors.white
                            : Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey.shade600
                                : Colors.grey.shade500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  GestureDetector(
                    onTap: () {
                      if (isRecording) {
                        _stopListening();
                      }
                      _audioPlayer.stop();
                      context.pop();
                    },
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey.shade800
                            : Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.2),
                      ),
                      child: Icon(
                        FeatherIcons.x,
                        size: 30,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey.shade400
                            : Colors.blue.shade600,
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
