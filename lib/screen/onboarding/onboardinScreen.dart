// main onboarding page with animated background
import 'package:flutter/material.dart';
import 'package:inzone/router/routes.dart';
import 'package:go_router/go_router.dart';

class OnboardPage extends StatefulWidget {
  const OnboardPage({super.key});

  @override
  State<OnboardPage> createState() => _OnboardPageState();
}

class _OnboardPageState extends State<OnboardPage>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isNavigating = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // List of screen keys matching the header map
  final List<String> _screenKeys = [
    'feed',
    'group',
    'msg',
    'post',
    'ai',
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation =
        Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);
    _animationController.forward();
  }

  // Get the correct image based on current theme mode
  Widget _getScreenImage(String key, bool isDarkMode) {
    final String imagePath =
        'assets/onboarding/${key}_${isDarkMode ? 'dark' : 'light'}.PNG';

    // Use Image.asset with error builder to handle missing assets
    return Image.asset(
      imagePath,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        debugPrint('Error loading image: $imagePath');
        debugPrint('Error details: $error');

        // Return a colored container as fallback
        return Container(
          color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
          child: Center(
            child: Text(
              key.toUpperCase(),
              style: TextStyle(
                color: isDarkMode ? Colors.white70 : Colors.black54,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }

  final Map<String, String> _header = {
    'feed': 'Enjoy the best content online handpicked just for you.',
    'group':
        'Chat about live games with pro athletes, favorite movies with the stars, or throw down your hottest music takes with the artists.',
    'msg':
        'Amazing one-on-one chats and group conversations. Chat with your favorite personas on anything from math homework to summer plans.',
    'post':
        'Share your amazing content and earn real cash when other users tip your creativity.',
    'ai':
        'Contribute to the community by creating amazing characters and avatars.',
  };

  void _navigateToIntroduction() {
    if (!_isNavigating) {
      setState(() {
        _isNavigating = true;
      });

      // Navigate using GoRouter for consistency with the rest of the app
      GoRouter.of(context).go(Routes.login);
    }
  }

  void _goToNextPage() {
    if (_currentPage < _screenKeys.length - 1) {
      _animationController.reverse().then((_) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 1),
          curve: Curves.easeInOut,
        );
        _animationController.forward();
      });
    } else {
      _navigateToIntroduction();
    }
  }

  void _goToPreviousPage() {
    if (_currentPage > 0) {
      _animationController.reverse().then((_) {
        _pageController.previousPage(
          duration: const Duration(milliseconds: 1),
          curve: Curves.easeInOut,
        );
        _animationController.forward();
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: GestureDetector(
        // Make the entire screen respond to swipe gestures
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity! < -10) {
            // Swipe left - go to next page
            _goToNextPage();
          } else if (details.primaryVelocity! > 10) {
            // Swipe right - go to previous page
            _goToPreviousPage();
          }
        },
        child: Stack(
          children: [
            // Background
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: Container(
                key: ValueKey<int>(_currentPage),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isDarkMode
                        ? [
                            Colors.black,
                            Colors.blueAccent.shade700,
                          ]
                        : [
                            Colors.white,
                            Colors.blueAccent.shade100,
                          ],
                  ),
                ),
              ),
            ),
            Container(
                color: (isDarkMode ? Colors.black : Colors.white)
                    .withOpacity(0.3)),

            // Logo at top center
            Positioned(
              top: 50,
              left: 0,
              right: 0,
              child: Center(
                child: Hero(
                  tag: 'logo',
                  child: Image.asset(
                    'assets/auth/logo.png',
                    height: 60,
                    width: 60,
                    errorBuilder: (context, error, stackTrace) {
                      debugPrint('Error loading logo: $error');
                      return const SizedBox(
                        height: 60,
                        width: 60,
                        child: Icon(Icons.image_not_supported,
                            color: Colors.white),
                      );
                    },
                  ),
                ),
              ),
            ),

            // PageView for navigation only (invisible)
            Positioned.fill(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (int page) {
                  setState(() => _currentPage = page);
                },
                children: List.generate(
                    _screenKeys.length, (index) => const SizedBox.shrink()),
              ),
            ),

            // Animated Text
            Positioned(
              top: 200,
              left: 0,
              right: 0,
              child: SizedBox(
                height: 100,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      _header[_screenKeys[_currentPage]] ?? '',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),

            // Device frame with changing screen content
            Positioned(
              bottom: -250,
              left: 0,
              right: 0,
              child: Center(
                child: SizedBox(
                  width: 350,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isDarkMode
                              ? Colors.grey[800]!
                              : Colors.grey[300]!,
                          width: 10,
                        ),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: AspectRatio(
                        aspectRatio: 9 / 19.5,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: _getScreenImage(
                                _screenKeys[_currentPage], isDarkMode),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Page indicator dots
            Positioned(
              top: 110,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_screenKeys.length, (index) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 16 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? (isDarkMode ? Colors.white : Colors.black)
                          : (isDarkMode
                              ? Colors.grey.withOpacity(0.4)
                              : Colors.grey.withOpacity(0.6)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
