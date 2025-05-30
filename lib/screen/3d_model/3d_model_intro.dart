import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inzone/router/routes.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inzone/components/ui/button.dart';

class ModelIntroScreen extends StatefulWidget {
  const ModelIntroScreen({super.key});

  // Static method to check if intro has been shown
  static Future<bool> hasSeenIntro() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('has_seen_3d_intro') ?? false;
  }

  // Static method to mark intro as seen
  static Future<void> markIntroAsSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_3d_intro', true);
  }

  @override
  State<ModelIntroScreen> createState() => _ModelIntroScreenState();
}

class _ModelIntroScreenState extends State<ModelIntroScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeInAnimation;
  late Animation<double> _modelFadeAnimation;
  late Animation<double> _buttonFadeAnimation;
  late Animation<double> _titleSlideAnimation;
  late Animation<double> _backgroundAnimation;

  // 화려한 색상 팔레트 정의
  static const List<Color> colorPalette = [
    Color(0xFF4A00E0), // 보라색
    Color(0xFF8E2DE2), // 자주색
    Color(0xFF5E35B1), // 딥 퍼플
    Color(0xFF3949AB), // 인디고
    Color(0xFF1976D2), // 블루
  ];

  // 그라데이션 정의 - 더 예쁘게 수정
  final LinearGradient _titleGradient = const LinearGradient(
    colors: [
      Color(0xFF4A00E0), // 보라색
      Color(0xFF8E2DE2), // 자주색
      Color(0xFF1976D2), // 블루
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  final List<String> _3dAssets = [
    'assets/3d/first.glb',
    'assets/3d/second.glb',
    'assets/3d/third.glb',
    'assets/3d/forth.glb',
  ];

  final List<String> _modelTitles = [
    'Explore 3D Models',
    'Create Your Character',
    'Customize Appearances',
    'Bring Your Ideas to Life',
  ];

  final Flutter3DController _3dController = Flutter3DController();
  int _currentModelIndex = 0;
  bool _isChangingModel = false;
  double _modelLoadingProgress = 0.0;
  bool _isNavigating = false;
  bool _showPlatform = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 5), // Total animation duration
      vsync: this,
    );

    _fadeInAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.05, curve: Curves.easeInOut),
      ),
    );

    _modelFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.05, 0.15, curve: Curves.easeInOut),
      ),
    );

    _buttonFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.15, 0.25, curve: Curves.easeInOut),
      ),
    );

    _titleSlideAnimation = Tween<double>(
      begin: 50.0,
      end: 0.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.1, curve: Curves.easeOut),
      ),
    );

    _backgroundAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.3, curve: Curves.easeInOut),
      ),
    );

    // Listen to model loading state
    _3dController.onModelLoaded.addListener(() {
      if (_3dController.onModelLoaded.value && mounted) {
        // When model is loaded, start animations if available
        _tryPlayAnimation();

        // Show the platform after model is loaded
        setState(() {
          _showPlatform = true;
        });
      }
    });

    _controller.forward();

    // Change model every 3 seconds
    Future.delayed(const Duration(milliseconds: 3000), () {
      _startModelRotation();
    });
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

  void _startModelRotation() {
    if (mounted) {
      Future.delayed(const Duration(milliseconds: 3000), () {
        if (mounted) {
          setState(() {
            _isChangingModel = true;
            _showPlatform = false;
          });

          Future.delayed(const Duration(milliseconds: 350), () {
            if (mounted) {
              setState(() {
                _currentModelIndex =
                    (_currentModelIndex + 1) % _3dAssets.length;
                _isChangingModel = false;
                _modelLoadingProgress = 0.0;
              });

              // 모델이 로드된 후 플랫폼을 보여줄 것이므로, 여기서는 보여주지 않음
              _startModelRotation(); // Schedule next change
            }
          });
        }
      });
    }
  }

  void _navigateToPromptScreen() async {
    // Mark intro as seen before navigating
    await ModelIntroScreen.markIntroAsSeen();
    if (mounted) {
      // Fade out the current screen
      setState(() {
        _isNavigating = true;
      });

      // Wait for the fade out animation
      await Future.delayed(const Duration(milliseconds: 400));

      if (mounted) {
        // Navigate to prompt screen with fade transition
        context.push(
          Routes.create3dModel,
          extra: {'transition': 'fade'},
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // 회전하는 플랫폼 위젯 - 더 차분하게 수정
  Widget _buildRotatingPlatform() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: _controller.value * 2 * math.pi,
          child: Container(
            width: 220,
            height: 40,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  colorPalette[0].withOpacity(0.5),
                  colorPalette[0].withOpacity(0.0),
                ],
                stops: const [0.3, 1.0],
              ),
              shape: BoxShape.circle,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Base circle
                Container(
                  width: 160,
                  height: 20,
                  decoration: BoxDecoration(
                    color: colorPalette[0].withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                ),
                // Wave effect
                ...List.generate(3, (index) {
                  // 파동 효과 개수 줄임
                  final delay = index * 0.3;
                  return AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      final value = ((_controller.value * 2) + delay) % 1.0;
                      return Opacity(
                        opacity: 1.0 - value,
                        child: Container(
                          width: 160 + (value * 60),
                          height: 20 + (value * 10),
                          decoration: BoxDecoration(
                            color: colorPalette[0]
                                .withOpacity(0.05 * (1.0 - value)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // 배경색 단순하게 변경
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
            ),
          ),

          // 메인 콘텐츠
          AnimatedOpacity(
            duration: const Duration(milliseconds: 400),
            opacity: _isNavigating ? 0.0 : 1.0,
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 제목 다시 예쁘게 스타일링
                  AnimatedBuilder(
                    animation: _fadeInAnimation,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _fadeInAnimation.value,
                        child: Transform.translate(
                          offset: Offset(0, _titleSlideAnimation.value),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 50, bottom: 10),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24),
                                  child: ShaderMask(
                                    shaderCallback: (bounds) =>
                                        _titleGradient.createShader(bounds),
                                    child: const Text(
                                      'Explore the 3D World',
                                      style: TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  child: Text(
                                    _modelTitles[_currentModelIndex],
                                    key: ValueKey<int>(_currentModelIndex),
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.color
                                          ?.withOpacity(0.7),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  // 3D model in the center with backdrop filter
                  Expanded(
                    child: AnimatedBuilder(
                      animation: _modelFadeAnimation,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _modelFadeAnimation.value,
                          child: Center(
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 350),
                              opacity: _isChangingModel ? 0.0 : 1.0,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // 3D 모델 주변 장식적 원 - 더 차분한 스타일로 수정
                                  Container(
                                    width: 280,
                                    height: 280,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color:
                                            colorPalette[0].withOpacity(0.08),
                                        width: 1,
                                      ),
                                    ),
                                  ),

                                  Container(
                                    width: 320,
                                    height: 320,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color:
                                            colorPalette[0].withOpacity(0.04),
                                        width: 1,
                                      ),
                                    ),
                                  ),

                                  // 3D 모델 뷰어
                                  SizedBox(
                                    height: 350,
                                    width: double.infinity,
                                    child: AbsorbPointer(
                                      absorbing: true, // 모든 사용자 입력 차단
                                      child: Flutter3DViewer(
                                        controller: _3dController,
                                        src: _3dAssets[_currentModelIndex],
                                        activeGestureInterceptor: false,
                                        enableTouch: false,
                                        progressBarColor: colorPalette[0],
                                        onProgress: (double progressValue) {
                                          setState(() {
                                            _modelLoadingProgress =
                                                progressValue;
                                          });
                                        },
                                        onLoad: (String modelAddress) {
                                          debugPrint(
                                              '3D model loaded: $modelAddress');
                                          setState(() {
                                            _showPlatform = true;
                                          });
                                        },
                                        onError: (String error) {
                                          debugPrint('3D model error: $error');
                                        },
                                      ),
                                    ),
                                  ),

                                  // 로딩 인디케이터
                                  if (_modelLoadingProgress < 1.0 &&
                                      !_3dController.onModelLoaded.value)
                                    SizedBox(
                                      width: 60,
                                      height: 60,
                                      child: CircularProgressIndicator(
                                        value: _modelLoadingProgress,
                                        strokeWidth: 2,
                                        backgroundColor:
                                            colorPalette[0].withOpacity(0.1),
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                colorPalette[0]),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Get Started button at the bottom with gradient
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 24),
                    child: AnimatedBuilder(
                      animation: _buttonFadeAnimation,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _buttonFadeAnimation.value,
                          child: Container(
                            height: 56,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              color: colorPalette[0], // 단색으로 변경
                              boxShadow: [
                                BoxShadow(
                                  color: colorPalette[0].withOpacity(0.2),
                                  blurRadius: 8,
                                  spreadRadius: 0,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(28),
                                onTap: _navigateToPromptScreen,
                                child: const Center(
                                  child: Text(
                                    'Get Started',
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
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ThreeDController {
  // This is a placeholder for the 3D controller implementation
  // Actual implementation would depend on the 3D library used

  void rotateModel(double x, double y, double z) {
    // Implement rotation logic
  }

  void zoomModel(double factor) {
    // Implement zoom logic
  }

  void resetView() {
    // Implement reset view logic
  }
}
