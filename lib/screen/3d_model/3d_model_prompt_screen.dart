import 'dart:io';
import 'dart:math' as math;
import 'package:colorful_safe_area/colorful_safe_area.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:inzone/components/ui/button.dart';
import 'package:inzone/router/routes.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';
import 'package:inzone/data/avatar_data.dart';
import 'package:inzone/services/avatar_service.dart';
import 'package:lottie/lottie.dart';
import 'package:toasty_box/toast_service.dart';

class ModelPromptScreen extends StatefulWidget {
  const ModelPromptScreen({super.key});

  @override
  State<ModelPromptScreen> createState() => _ModelPromptScreenState();
}

class _ModelPromptScreenState extends State<ModelPromptScreen>
    with SingleTickerProviderStateMixin {
  // 화려한 색상 팔레트 정의
  static const List<Color> colorPalette = [
    Color(0xFF4A00E0), // 보라색
    Color(0xFF8E2DE2), // 자주색
    Color(0xFFFF4B2B), // 주황색
    Color(0xFFF857A6), // 핑크색
    Color(0xFF00CCFF), // 하늘색
  ];

  // 고정된 색상 사용 (랜덤 대신)
  Color getThemeColor(int index) {
    return colorPalette[index % colorPalette.length];
  }

  // 고정된 그라데이션 사용
  LinearGradient getGradient() {
    return const LinearGradient(
      colors: [Color(0xFF4A00E0), Color(0xFFF857A6)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final Flutter3DController _3dController = Flutter3DController();
  final AvatarService _avatarService = AvatarService();
  final FocusNode _promptFocusNode = FocusNode();

  bool _isGenerating = false;
  String? _previewModelUrl;
  AvatarData? _generatedAvatar;
  bool _showNameInput = false;
  late LinearGradient _currentGradient;
  DateTime? _generationStartTime;

  // 타이머 관련 변수
  int _elapsedSeconds = 0;
  static const int _maxWaitTimeInSeconds = 300; // 5분

  late AnimationController _rotationController;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();

    // 초기 그라데이션 설정
    _currentGradient = getGradient();

    // Setup rotation animation for the base platform
    _rotationController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 2 * math.pi, // Full rotation (2π)
    ).animate(_rotationController);
  }

  @override
  void dispose() {
    _promptController.dispose();
    _nameController.dispose();
    _promptFocusNode.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  void _generateCharacter() async {
    if (_promptController.text.trim().isEmpty) {
      return;
    }

    // Hide keyboard
    FocusScope.of(context).unfocus();

    setState(() {
      _isGenerating = true;
      _generationStartTime = DateTime.now();
      _elapsedSeconds = 0;
    });

    // 타이머 시작 - 매 초마다 경과 시간 업데이트
    Future.doWhile(() async {
      if (!_isGenerating || !mounted) return false;
      await Future.delayed(const Duration(seconds: 1));
      if (mounted && _isGenerating && _generationStartTime != null) {
        setState(() {
          _elapsedSeconds =
              DateTime.now().difference(_generationStartTime!).inSeconds;
        });
      }
      return _isGenerating && mounted;
    });

    try {
      // Call the actual API to generate a 3D model
      AvatarData avatar;
      try {
        avatar = await _avatarService.generateAvatar(
          _promptController.text.trim(),
        );
      } catch (apiError) {
        // API 오류 발생 시 Mock 데이터 사용
        debugPrint('API error occurred: $apiError, using mock data instead');
        avatar = await _avatarService.generateMockAvatar(
          _promptController.text.trim(),
        );
      }

      if (mounted) {
        setState(() {
          _generatedAvatar = avatar;
          _previewModelUrl = avatar.modelGlb;
          _isGenerating = false;
          _generationStartTime = null;
        });

        // Start animation if available after model is loaded
        _3dController.onModelLoaded.addListener(() {
          if (_3dController.onModelLoaded.value) {
            _tryPlayAnimation();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _generationStartTime = null;
        });
      }
    }
  }

  void _tryPlayAnimation() async {
    try {
      final animations = await _3dController.getAvailableAnimations();
      if (animations.isNotEmpty) {
        _3dController.playAnimation();
      }
    } catch (e) {
      debugPrint('No animations available: $e');
    }
  }

  void _continueWithAvatar() {
    setState(() {
      _showNameInput = true;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _buildNameInputBottomSheet();
      },
    );
  }

  Widget _buildNameInputBottomSheet() {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Name Your Character',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Theme.of(context).dividerColor,
                ),
              ),
              child: TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  hintText: 'Enter character name',
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Button(
              text: 'Save Character',
              onPressed: () {
                if (_nameController.text.trim().isEmpty) {
                  return;
                }
                // Navigate to model selection screen with input data
                Navigator.pop(context); // Close the bottom sheet
                context.push(
                  Routes.create3dModelSelect,
                  extra: {
                    'prompt': _promptController.text.trim(),
                    'name': _nameController.text.trim(),
                    'avatar': _generatedAvatar?.toJson(),
                  },
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColorfulSafeArea(
      color: Theme.of(context).dialogBackgroundColor,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Theme.of(context).dialogBackgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: Padding(
            padding: const EdgeInsets.only(left: 12.0),
            child: GestureDetector(
              onTap: () {
                context.go(Routes.home);
              },
              child: CircleAvatar(
                radius: 22,
                backgroundColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey.shade800
                    : Colors.grey.shade200,
                child: Padding(
                  padding: const EdgeInsets.only(left: 5),
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
          title: ShaderMask(
            shaderCallback: (bounds) => _currentGradient.createShader(bounds),
            child: const Text(
              'Create 3D Character',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          centerTitle: true,
        ),
        body: Stack(
          children: [
            // 3D Model display in center
            Column(
              children: [
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 3D Model or placeholder
                        SizedBox(
                          height: 350,
                          width: double.infinity,
                          child: _previewModelUrl != null
                              ? Flutter3DViewer(
                                  controller: _3dController,
                                  src: _previewModelUrl!,
                                  activeGestureInterceptor: true,
                                  enableTouch: false,
                                  progressBarColor: colorPalette[0],
                                  onProgress: (double progress) {
                                    // Update loading progress
                                    setState(() {
                                      // Only show progress for remote URLs
                                      if (!_previewModelUrl!
                                          .startsWith('assets/')) {
                                        _isGenerating = progress < 1.0;
                                      }
                                    });
                                  },
                                  onLoad: (String url) {
                                    debugPrint('3D model loaded: $url');
                                    setState(() {
                                      _isGenerating = false;
                                    });
                                    // Try to play animation if available
                                    _tryPlayAnimation();
                                  },
                                  onError: (String error) {
                                    debugPrint('3D model error: $error');
                                    setState(() {
                                      _isGenerating = false;
                                      // Reset the preview URL to force a reload
                                      _previewModelUrl = null;
                                    });
                                    // Show error message
                                    ToastService.showToast(
                                      context,
                                      backgroundColor:
                                          Theme.of(context).canvasColor,
                                      shadowColor: Colors.transparent,
                                      leading: const Icon(
                                        FeatherIcons.xCircle,
                                        color: Colors.redAccent,
                                      ),
                                      message:
                                          'Failed to load 3D model: $error',
                                    );
                                  },
                                )
                              : _isGenerating
                                  ? _buildLoadingAnimation()
                                  : _buildEmptyState(),
                        ),

                        // Rotating base platform
                        if (_previewModelUrl != null || _isGenerating)
                          _buildRotatingPlatform(),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Bottom action button for continuing
            if (_previewModelUrl != null && !_isGenerating)
              Positioned(
                bottom: 86,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: _currentGradient,
                      boxShadow: [
                        BoxShadow(
                          color: colorPalette[0].withOpacity(0.3),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(28),
                        onTap: _continueWithAvatar,
                        child: const Center(
                          child: Text(
                            'Continue with this Character',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        bottomSheet: // Bottom prompt input
            Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 60,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(30),
                  gradient: LinearGradient(
                    colors: [
                      colorPalette[2].withOpacity(0.1),
                      colorPalette[4].withOpacity(0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: Colors.transparent,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 5,
                      spreadRadius: 1,
                    )
                  ],
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: colorPalette[0].withOpacity(0.1),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        Icons.auto_awesome,
                        size: 20,
                        color: colorPalette[0],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _promptController,
                        focusNode: _promptFocusNode,
                        decoration: InputDecoration(
                          hintText: 'Describe your character...',
                          hintStyle: TextStyle(
                            color: Theme.of(context).hintColor.withOpacity(0.7),
                            fontWeight: FontWeight.w400,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 16),
                          fillColor: Colors.transparent,
                        ),
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                        onSubmitted: (_) => _generateCharacter(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _isGenerating
                            ? Colors.grey.withOpacity(0.3)
                            : colorPalette[0],
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: _isGenerating
                            ? null
                            : [
                                BoxShadow(
                                  color: colorPalette[0].withOpacity(0.3),
                                  blurRadius: 5,
                                  spreadRadius: 1,
                                ),
                              ],
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.arrow_upward_rounded,
                          size: 20,
                          color: _isGenerating ? Colors.grey : Colors.white,
                        ),
                        onPressed: _isGenerating ? null : _generateCharacter,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingAnimation() {
    // 남은 시간 계산
    final int remainingSeconds = _maxWaitTimeInSeconds - _elapsedSeconds;
    final int minutes = remainingSeconds ~/ 60;
    final int seconds = remainingSeconds % 60;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 3D Lottie animation
        SizedBox(
          height: 200,
          width: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background glow effect
              Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: colorPalette[0].withOpacity(0.5),
                      blurRadius: 30,
                      spreadRadius: 10,
                    ),
                  ],
                ),
              ),

              // 3D Cube animation
              Lottie.network(
                'https://assets1.lottiefiles.com/packages/lf20_kkflmtur.json',
                width: 150,
                height: 150,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback animation if Lottie fails to load
                  return AnimatedBuilder(
                    animation: _rotationController,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _rotationController.value * 2 * math.pi,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                colorPalette[0],
                                colorPalette[1],
                              ],
                            ),
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: colorPalette[0].withOpacity(0.5),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Transform.rotate(
                              angle: -_rotationController.value * 4 * math.pi,
                              child: const Icon(
                                Icons.view_in_ar,
                                size: 40,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Glowing text with animation
        ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [
                colorPalette[0],
                colorPalette[1],
              ],
            ).createShader(bounds);
          },
          child: const Text(
            'Generating your character...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: 200,
          child: LinearProgressIndicator(
            backgroundColor: colorPalette[0].withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(colorPalette[0]),
            // 시간에 따른 진행 상황 표시
            value: _elapsedSeconds / _maxWaitTimeInSeconds,
          ),
        ),
        const SizedBox(height: 12),
        // 남은 시간 표시
        Text(
          'Time elapsed: ${_elapsedSeconds}s / Estimated time remaining: $minutes:${seconds.toString().padLeft(2, '0')}',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'This may take up to 5 minutes',
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 3D icon with animation
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                colorPalette[0].withOpacity(0.1),
                colorPalette[1].withOpacity(0.05),
              ],
            ),
            shape: BoxShape.circle,
          ),
          child: ShaderMask(
            shaderCallback: (bounds) {
              return LinearGradient(
                colors: [
                  colorPalette[0],
                  colorPalette[1],
                ],
              ).createShader(bounds);
            },
            child: const Icon(
              Icons.view_in_ar,
              size: 60,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 24),
        ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [
                colorPalette[0],
                colorPalette[1],
              ],
            ).createShader(bounds);
          },
          child: const Text(
            'Create Your 3D Character',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'Type a detailed description below to generate a unique 3D character',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _suggestionChip(String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(label),
        backgroundColor: colorPalette[0].withOpacity(0.1),
        labelStyle: TextStyle(
          color: colorPalette[0],
          fontWeight: FontWeight.w400,
        ),
        onPressed: () {
          // Append to the current prompt or set if empty
          if (_promptController.text.isEmpty) {
            _promptController.text = label;
          } else {
            _promptController.text += ", $label";
          }
          // Move cursor to the end
          _promptController.selection = TextSelection.fromPosition(
            TextPosition(offset: _promptController.text.length),
          );
        },
      ),
    );
  }

  // Improved rotating platform with wave effect
  Widget _buildRotatingPlatform() {
    // 고정 색상 사용
    final baseColor = colorPalette[0];
    final waveColor = colorPalette[1];

    return AnimatedBuilder(
      animation: _rotationAnimation,
      builder: (context, child) {
        return Transform.rotate(
          angle: _rotationAnimation.value,
          child: Container(
            width: 220,
            height: 40,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  baseColor.withOpacity(0.7),
                  baseColor.withOpacity(0.0),
                ],
                stops: const [0.3, 1.0],
              ),
              shape: BoxShape.circle,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // // Base circle
                // Container(
                //   width: 160,
                //   height: 20,
                //   decoration: BoxDecoration(
                //     color: baseColor.withOpacity(0.3),
                //     shape: BoxShape.circle,
                //   ),
                // ),
                // Wave effect
                ...List.generate(6, (index) {
                  final delay = index * 0.3;
                  return AnimatedBuilder(
                    animation: _rotationController,
                    builder: (context, child) {
                      final value =
                          ((_rotationController.value * 2) + delay) % 1.0;
                      return Opacity(
                        opacity: 1.0 - value,
                        child: Container(
                          width: 160 + (value * 60),
                          height: 20 + (value * 10),
                          decoration: BoxDecoration(
                            color: waveColor.withOpacity(0.1 * (1.0 - value)),
                            shape: BoxShape.circle,
                          ),
                        ),
                      );
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}
