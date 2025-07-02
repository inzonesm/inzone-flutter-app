import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:inzone/components/ui/button.dart';
import 'package:inzone/services/inzone_database.dart';
import 'package:colorful_safe_area/colorful_safe_area.dart';
import 'package:lottie/lottie.dart';
import 'dart:math' as math;
import 'package:go_router/go_router.dart';
import 'package:inzone/router/routes.dart';
import 'package:toasty_box/toast_service.dart';

class AICharacterSelectionScreen extends StatefulWidget {
  final String name;
  final String prompt;
  final String profilePictureUrl;
  final String characterId;
  final List<String>? candidateImages;
  const AICharacterSelectionScreen({
    super.key,
    required this.name,
    required this.prompt,
    required this.profilePictureUrl,
    required this.characterId,
    this.candidateImages,
  });

  @override
  State<AICharacterSelectionScreen> createState() =>
      _AICharacterSelectionScreenState();
}

class _AICharacterSelectionScreenState extends State<AICharacterSelectionScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isLoading = false;
  List<Map<String, dynamic>> _characters = [];
  String? _errorMessage;

  // Controller and current page for image scrolling
  final PageController _imagePageController =
      PageController(viewportFraction: 0.7);
  int _currentImagePage = 0;

  // Selected image index (-1 means none selected)
  int _selectedImageIndex = -1;

  // Generated character information
  Map<String, dynamic>? _generatedCharacter;

  // Controller for the prompt input
  final TextEditingController _promptController = TextEditingController();
  final FocusNode _promptFocusNode = FocusNode();

  // Controllers for form fields
  final TextEditingController _nameFieldController = TextEditingController();
  final TextEditingController _genderFieldController = TextEditingController();
  final TextEditingController _ageFieldController = TextEditingController();
  final TextEditingController _eyeColorFieldController =
      TextEditingController();
  final TextEditingController _DescriptionFieldController =
      TextEditingController();

  // Controller for the character name input
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();

  bool _isGenerating = false;
  bool _isFormExpanded = false;

  // Animation controller for rotating effects
  late AnimationController _rotationController;
  late Animation<double> _rotationAnimation;

  // Animation controller for form expansion
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;

  // Color palette definition (same as 3D model screen)
  static const List<Color> colorPalette = [
    Color(0xFF2196F3), // Blue (Main color)
    Color(0xFF8E2DE2), // Purple
    Color(0xFFFF4B2B), // Orange
    Color(0xFFF857A6), // Pink
    Color(0xFF00CCFF), // Sky blue
  ];

  // Gradient definition
  late LinearGradient _currentGradient;

  @override
  void initState() {
    super.initState();
    // Set character information if provided from the widget
    if (widget.characterId.isNotEmpty) {
      _generatedCharacter = {
        'Name': widget.name,
        'Personality': widget.prompt,
        'profilePictureUrl': widget.profilePictureUrl,
        'PopularCharacterId': widget.characterId,
        'candidate_images': widget.candidateImages ?? [],
      };
    }

    // Initialize gradient with blue colors
    _currentGradient = const LinearGradient(
      colors: [Color(0xFF2196F3), Color(0xFF03A9F4)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    // Setup rotation animation
    _rotationController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 2 * math.pi, // Full rotation (2π)
    ).animate(_rotationController);

    // Setup expand animation
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOut,
    );
  }

  Future<void> _loadCharacters() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Fetch AI characters from API
      final apiCharacters = await InZoneDatabase.getAICharacters(popular: true);

      if (apiCharacters != null && mounted) {
        setState(() {
          _characters = List<Map<String, dynamic>>.from(apiCharacters);
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load characters';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _generateCharacter() async {
    if (_promptController.text.trim().isEmpty) {
      ToastService.showToast(
        context,
        backgroundColor: Theme.of(context).canvasColor,
        shadowColor: Colors.transparent,
        leading: const Icon(
          FeatherIcons.xCircle,
          color: Colors.redAccent,
        ),
        message: 'Please enter a character description',
      );
      return;
    }

    // Hide keyboard
    FocusScope.of(context).unfocus();

    setState(() {
      _isGenerating = true;
      _isLoading = true; // Show loading state
      _isFormExpanded = false; // Collapse the form
    });

    // Reverse the animation
    _expandController.reverse(from: 1.0);

    try {
      // Call the API to create popular character
      final result = await InZoneDatabase.createPopularCharacter(
        greeting: "Hello! I'm a new character. Let's chat!",
        name: _nameFieldController.text.isEmpty
            ? "AI Character"
            : _nameFieldController.text,
        personality: _promptController.text.trim(),
        numberOfChats: 0,
        profilePictureUrl: "", // Empty for now
        votes: 0,
        createdByHuman: true,
      );

      // Output result (for debugging)
      print("PPPPPPPPPPPP$result");

      if (result["success"] == true && mounted) {
        // Check if we have candidate images
        List<dynamic> candidateImages =
            result["data"]["candidate_images"] ?? [];

        setState(() {
          _isLoading = false;
          // Keep _isGenerating true if we have images, so the prompt stays collapsed
          _isGenerating = candidateImages.isNotEmpty;

          // Save generated character info - using the same field names as before
          _generatedCharacter = {
            'Name': result["data"]["Name"] ??
                (_nameFieldController.text.isEmpty
                    ? "AI Character"
                    : _nameFieldController.text),
            'Personality': _promptController.text.trim(),
            'profilePictureUrl': result["data"]["profile_picture_url"] ?? "",
            'PopularCharacterId': result["data"]["PopularCharacterId"] ?? "",
            'candidate_images': candidateImages,
          };

          // Select the first image by default
          if (candidateImages.isNotEmpty) {
            _selectedImageIndex = 0;
          }
        });
      } else {
        // Error - show error message
        if (mounted) {
          String errorMessage = result["error"] ?? "Failed to create character";
          setState(() {
            _errorMessage = 'Error: $errorMessage';
            _isLoading = false;
            // Keep _isGenerating true to show retry button
          });

          // Display error message using ToastService
          ToastService.showToast(
            context,
            backgroundColor: Theme.of(context).canvasColor,
            shadowColor: Colors.transparent,
            leading: const Icon(
              FeatherIcons.xCircle,
              color: Colors.redAccent,
            ),
            message: 'Error: $errorMessage',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error: $e';
          _isLoading = false;
          // Keep _isGenerating true to show retry button
        });

        // Display exception message using ToastService
        ToastService.showToast(
          context,
          backgroundColor: Theme.of(context).canvasColor,
          shadowColor: Colors.transparent,
          leading: const Icon(
            FeatherIcons.xCircle,
            color: Colors.redAccent,
          ),
          message: 'Unexpected error: $e',
        );
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _promptController.dispose();
    _promptFocusNode.dispose();
    _nameController.dispose();
    _nameFocusNode.dispose();
    _rotationController.dispose();
    _imagePageController.dispose();
    _expandController.dispose();

    // Dispose form field controllers
    _nameFieldController.dispose();
    _genderFieldController.dispose();
    _ageFieldController.dispose();
    _eyeColorFieldController.dispose();
    _DescriptionFieldController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColorfulSafeArea(
      color: Theme.of(context).dialogBackgroundColor,
      child: Scaffold(
        backgroundColor: Theme.of(context).dialogBackgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: Padding(
            padding: const EdgeInsets.only(left: 12.0),
            child: GestureDetector(
              onTap: () {
                Navigator.pop(context);
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
            shaderCallback: (bounds) {
              return LinearGradient(
                colors: [
                  colorPalette[0],
                  colorPalette[1],
                ],
              ).createShader(bounds);
            },
            child: const Text(
              'Generate AI Character ',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          centerTitle: true,
        ),
        body: _isLoading
            ? _buildLoadingState()
            : _errorMessage != null
                ? _buildErrorState()
                : _generatedCharacter != null
                    ? _buildGeneratedCharacter()
                    : _buildEmptyState(),
        bottomSheet: Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
          child: _generatedCharacter != null && _hasValidImageSelection()
              ? _buildSelectButton()
              : _buildPromptInput(),
        ),
      ),
    );
  }

  // Build empty state
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
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
              'Create Your AI Character',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Fill in the character details in the form below to create your unique AI character',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // Build loading state
  Widget _buildLoadingState() {
    return Center(
      child: Column(
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
                Lottie.asset(
                  'assets/animations/animation_intro.json', // Path to your Lottie animation
                  width: 200, // You can adjust the size as needed
                  height: 200,
                  fit: BoxFit.cover,
                ),

                // Loading indicator
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.transparent),
                  strokeWidth: 5,
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
              'Creating your character...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),

          if (_promptController.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.3, end: 0.9),
                duration: const Duration(milliseconds: 1500),
                curve: Curves.easeInOut,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: child,
                  );
                },
                child: Text(
                  "Generating your character. This may take up to 10 seconds...",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                    fontStyle: FontStyle.italic,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingInfoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$label: ",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.color
                  ?.withOpacity(0.8),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.color
                    ?.withOpacity(0.7),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // Build error state
  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 80,
            color: colorPalette[2],
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? 'An error occurred',
            style: const TextStyle(
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _errorMessage = null;
                _isGenerating = false;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colorPalette[0],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // Generated character screen
  Widget _buildGeneratedCharacter() {
    final name = _generatedCharacter?['Name'] ?? 'AI Character';
    final description = _generatedCharacter?['Personality'] ?? '';
    final profilePictureUrl = _generatedCharacter?['profilePictureUrl'] ?? '';
    final candidateImages =
        _generatedCharacter?['candidate_images'] as List<dynamic>? ?? [];

    // Initialize name controller
    if (_nameController.text.isEmpty) {
      _nameController.text = name;
    }

    // Use candidate images if available, otherwise fallback to profile picture
    final List<String> characterImages = candidateImages.isNotEmpty
        ? candidateImages.map((image) => image.toString()).toList()
        : [profilePictureUrl];

    // Debug image URLs
    print("Candidate Images: $candidateImages");
    print("Character Images: $characterImages");

    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Add top margin to move image down
          const SizedBox(height: 30),

          // Image scroll view - increased size and centered
          SizedBox(
            height: 350, // Increased image area size
            child: PageView.builder(
              itemCount: characterImages.length,
              controller: _imagePageController,
              onPageChanged: (index) {
                setState(() {
                  _currentImagePage = index;
                });
              },
              itemBuilder: (context, index) {
                return Center(
                  child: _buildCharacterImage(characterImages[index], index),
                );
              },
            ),
          ),

          // Page indicator
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              characterImages.length,
              (index) => Container(
                width: 8.0,
                height: 8.0,
                margin: const EdgeInsets.symmetric(horizontal: 4.0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: index == _currentImagePage
                      ? colorPalette[0]
                      : Colors.grey.withOpacity(0.3),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          Container(
            width: MediaQuery.of(context).size.width * 0.85,
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey.shade800.withOpacity(0.7)
                  : Colors.white.withOpacity(0.9),
              gradient: LinearGradient(
                colors: [
                  colorPalette[0].withOpacity(0.1),
                  colorPalette[1].withOpacity(0.1)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? colorPalette[0].withOpacity(0.4)
                    : colorPalette[0].withOpacity(0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.black.withOpacity(0.3)
                      : Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _nameController,
              focusNode: _nameFocusNode,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                hintText: 'Enter character name',
                hintStyle: TextStyle(
                  color: Theme.of(context).hintColor.withOpacity(0.7),
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                fillColor: Colors.transparent,
                filled: true,
              ),
              onChanged: (value) {
                // Update character info when the name changes
                if (_generatedCharacter != null) {
                  setState(() {
                    _generatedCharacter!['Name'] = value;
                  });
                }
              },
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Your selected AI character will be used for chat by both you and all InZone users.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.withOpacity(0.7),
            ),
          ),

          const SizedBox(height: 60),
        ],
      ),
    );
  }

  // Character image widget
  Widget _buildCharacterImage(String imageUrl, int index) {
    final bool isSelected = _selectedImageIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedImageIndex = index;
        });
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Image container
          Container(
            width: 250, // Increased image size
            height: 250, // Increased image size
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(color: colorPalette[0], width: 3)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? colorPalette[0].withOpacity(0.5)
                      : colorPalette[0].withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: imageUrl.isNotEmpty
                ? ClipOval(
                    child: Image.network(
                      imageUrl,
                      width: 250, // Increased image size
                      height: 250, // Increased image size
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        print("Image error: $error");
                        return Center(
                          child: Icon(
                            CupertinoIcons.person_fill,
                            size: 120, // Increased icon size
                            color: colorPalette[0],
                          ),
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(colorPalette[0]),
                          ),
                        );
                      },
                    ),
                  )
                : Center(
                    child: Icon(
                      CupertinoIcons.person_fill,
                      size: 120, // Increased icon size
                      color: colorPalette[0],
                    ),
                  ),
          ),

          // Check mark - show on all images but style based on selection
          Positioned(
            top: 10,
            right: 20,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected
                    ? colorPalette[0]
                    : Colors.white.withOpacity(0.7),
                shape: BoxShape.circle,
                border: isSelected
                    ? null
                    : Border.all(color: Colors.grey.withOpacity(0.5), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Icon(
                Icons.check,
                color: isSelected ? Colors.white : Colors.grey.withOpacity(0.5),
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Select button widget
  Widget _buildSelectButton() {
    final name = _nameController.text.isNotEmpty
        ? _nameController.text
        : (_generatedCharacter?['Name'] ?? 'AI Character');

    final candidateImages =
        _generatedCharacter?['candidate_images'] as List<dynamic>? ?? [];
    final selectedImageUrl = candidateImages.isNotEmpty &&
            _selectedImageIndex < candidateImages.length
        ? candidateImages[_selectedImageIndex].toString()
        : (_generatedCharacter?['profilePictureUrl'] ?? '');

    return ElevatedButton(
      onPressed: () {
        // Handle character selection with selected image
        final characterData = {
          'name': name,
          'personality': _generatedCharacter?['Personality'] ?? '',
          'characterId': _generatedCharacter?['PopularCharacterId'] ?? '',
          'selectedImageUrl': selectedImageUrl,
          'selectedImageIndex': _selectedImageIndex,
        };
        ToastService.showToast(
          context,
          shadowColor: Colors.transparent,
          backgroundColor: Theme.of(context).canvasColor,
          leading: const Icon(
            FeatherIcons.checkCircle,
            color: Colors.greenAccent,
          ),
          message:
              'Selected character: $name with image ${_selectedImageIndex + 1}',
        );

        context.pushReplacement(Routes.home);

        // Add navigation or callback logic here
        // For example: context.push(Routes.chatWithCharacter, extra: characterData);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: colorPalette[0],
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
        minimumSize: const Size(double.infinity, 56),
      ),
      child: const Text(
        'Continue with this character',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Prompt input widget
  Widget _buildPromptInput() {
    // If we have generated character with images, don't show the prompt input by default
    bool shouldHidePrompt = _generatedCharacter != null &&
        (_generatedCharacter!['candidate_images'] as List<dynamic>? ?? [])
            .isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500), // 애니메이션 시간 더 증가
      curve: Curves.easeOutQuart, // 더 부드러운 애니메이션 커브 적용
      height: (_isGenerating || shouldHidePrompt || !_isFormExpanded)
          ? 60
          : _calculateFormHeight(), // 폼의 높이를 계산하는 함수 사용
      width: MediaQuery.of(context).size.width,
      padding: (_isGenerating || shouldHidePrompt || !_isFormExpanded)
          ? const EdgeInsets.symmetric(vertical: 10, horizontal: 20)
          : const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey.shade800.withOpacity(0.8)
            : Colors.white.withOpacity(0.9),
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
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey.shade700.withOpacity(0.5)
              : Colors.grey.shade300.withOpacity(0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.05),
            blurRadius: 5,
            spreadRadius: 1,
          )
        ],
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.95, end: 1.0).animate(animation),
              child: child,
            ),
          );
        },
        child: (_isGenerating || shouldHidePrompt)
            ? _buildGeneratingState()
            : (_isFormExpanded
                ? _buildFormInputs()
                : GestureDetector(
                    onTap: () {
                      _toggleFormExpanded(true);
                    },
                    child: _buildCollapsedPrompt(),
                  )),
      ),
    );
  }

  // 폼의 높이를 계산하는 함수
  double _calculateFormHeight() {
    // 기본 높이 (패딩, 버튼, 간격 등)
    double baseHeight = 600;

    // Description 필드가 여러 줄일 경우 추가 높이
    if (_DescriptionFieldController.text.length > 50) {
      baseHeight += 40;
    }

    return baseHeight;
  }

  // Form inputs widget
  Widget _buildFormInputs() {
    return AnimatedBuilder(
      animation: _expandAnimation,
      builder: (context, child) {
        return SizedBox(
          width: double.infinity,
          child: FadeTransition(
            opacity: _expandAnimation,
            child: child,
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () {
                  _toggleFormExpanded(false);
                },
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close,
                    size: 18,
                    color: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.color
                        ?.withOpacity(0.7),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Form title
          // Name field
          const SizedBox(height: 10),
          _buildFormField('Name:', _nameFieldController, 'Steve'),
          const SizedBox(height: 12),

          // Gender field
          _buildFormField('Gender:', _genderFieldController, 'Male'),
          const SizedBox(height: 12),

          // Age field
          _buildFormField('Age:', _ageFieldController, '23'),
          const SizedBox(height: 12),

          // Celebrity field
          _buildFormField('Celebrity:', _eyeColorFieldController, 'Yes / No'),
          const SizedBox(height: 12),

          // Description field
          _buildFormField('Description:', _DescriptionFieldController,
              'Describe your character\'s interests, hobbies, or personality'),
          const SizedBox(height: 30),

          // Generate button
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: MediaQuery.of(context).size.width * 0.8,
                height: 60,
                decoration: BoxDecoration(
                  color: colorPalette[0],
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: colorPalette[0].withOpacity(0.3),
                      blurRadius: 5,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: TextButton(
                  onPressed: () {
                    // Combine all fields into a structured prompt
                    final prompt =
                        'Name: ${_nameFieldController.text.isEmpty ? "Steve" : _nameFieldController.text}\n'
                        'Gender: ${_genderFieldController.text.isEmpty ? "Male" : _genderFieldController.text}\n'
                        'Age: ${_ageFieldController.text.isEmpty ? "23" : _ageFieldController.text}\n'
                        'Celebrity: ${_eyeColorFieldController.text.isEmpty ? "Yes / No" : _eyeColorFieldController.text}\n'
                        'Description: ${_DescriptionFieldController.text.isEmpty ? "Video Games, Dogs, Music" : _DescriptionFieldController.text}';

                    // Set the prompt controller text
                    _promptController.text = prompt;

                    // Call generate character
                    _generateCharacter();

                    // Reverse the animation
                    _expandController.reverse(from: 1.0);
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    "Generate",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // Collapsed prompt state (tap to start input)
  Widget _buildCollapsedPrompt() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Center(
            child: Text(
              "Tap to create your AI character...",
              style: TextStyle(
                color: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.color
                    ?.withOpacity(0.7),
                fontStyle: FontStyle.italic,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  void _toggleFormExpanded(bool expanded) {
    setState(() {
      _isFormExpanded = expanded;
      if (expanded) {
        _expandController.forward(from: 0.0);
      } else {
        _expandController.reverse(from: 1.0);
      }
    });
  }

  // Helper method to build form fields
  Widget _buildFormField(
      String label, TextEditingController controller, String hintText) {
    // Determine if this is the Description field (which should be multi-line)
    bool isDescriptionField = label == 'Description:';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Theme.of(context).textTheme.headlineMedium?.color,
          ),
        ),
        const SizedBox(height: 4),
        // Input field
        Container(
          height: isDescriptionField ? 60 : 40,
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey.shade700.withOpacity(0.3)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey.shade600.withOpacity(0.5)
                  : Colors.grey.shade300,
              width: 1,
            ),
          ),
          child: TextField(
            controller: controller,
            maxLines: isDescriptionField ? 2 : 1,
            minLines: isDescriptionField ? 2 : 1,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(
                color: Theme.of(context).hintColor.withOpacity(0.5),
                fontSize: 14,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  // Generating state widget (horizontal bar with loading and prompt text)
  Widget _buildGeneratingState() {
    // If we have generated character with images, show a tap hint
    bool hasGeneratedCharacter = _generatedCharacter != null &&
        (_generatedCharacter!['candidate_images'] as List<dynamic>? ?? [])
            .isNotEmpty;
    bool hasError = _errorMessage != null;

    String userInputSummary = '';
    if (_nameFieldController.text.isNotEmpty) {
      userInputSummary += '${_nameFieldController.text}, ';
    }
    if (_genderFieldController.text.isNotEmpty) {
      userInputSummary += '${_genderFieldController.text}, ';
    }
    if (_ageFieldController.text.isNotEmpty) {
      userInputSummary += '${_ageFieldController.text}, ';
    }
    if (_eyeColorFieldController.text.isNotEmpty) {
      userInputSummary += '${_eyeColorFieldController.text}, ';
    }
    if (_DescriptionFieldController.text.isNotEmpty) {
      userInputSummary += _DescriptionFieldController.text;
    }
    if (userInputSummary.endsWith(', ')) {
      userInputSummary =
          userInputSummary.substring(0, userInputSummary.length - 2);
    }

    return GestureDetector(
      onTap: () {
        if (hasGeneratedCharacter || hasError) {
          setState(() {
            _isGenerating = false;
          });
          _toggleFormExpanded(true);
        }
      },
      child: Row(
        children: [
          // Loading indicator or tap icon
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: hasGeneratedCharacter
                  ? Icon(
                      Icons.edit,
                      color: colorPalette[0],
                      size: 20,
                    )
                  : hasError
                      ? const Icon(
                          Icons.error_outline,
                          color: Colors.redAccent,
                          size: 20,
                        )
                      : SizedBox(
                          width: 24,
                          height: 24,
                          child: ShaderMask(
                            shaderCallback: (Rect bounds) {
                              return LinearGradient(
                                colors: [
                                  colorPalette[0],
                                  colorPalette[1],
                                ],
                              ).createShader(bounds);
                            },
                            child: const CircularProgressIndicator(
                              strokeWidth: 2.5,
                            ),
                          ),
                        ),
            ),
          ),
          const SizedBox(width: 15),

          // Faded prompt text or tap hint
          Expanded(
            child: AnimatedOpacity(
              opacity: 0.7,
              duration: const Duration(milliseconds: 500),
              child: Text(
                hasError
                    ? "Error: ${_errorMessage?.replaceAll('Error: ', '')}"
                    : hasGeneratedCharacter
                        ? "Tap to edit character details"
                        : userInputSummary.isNotEmpty
                            ? userInputSummary
                            : "Generating your character...",
                style: TextStyle(
                  color: hasError
                      ? Colors.redAccent
                      : Theme.of(context).textTheme.bodyMedium?.color,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          // Retry button (visible when error occurs or loading completes)
          if (_errorMessage != null || hasGeneratedCharacter)
            TextButton(
              onPressed: () {
                setState(() {
                  _isGenerating = false;
                  _errorMessage = null;
                });
                _toggleFormExpanded(true);
              },
              child: Text(
                _errorMessage != null ? "Retry" : "Edit",
                style: TextStyle(
                  color: colorPalette[0],
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Character list (original code) - not used now
  Widget _buildCharacterList() {
    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _characters.length + 1, // +1 for user's character
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  return _buildCharacterItem(index);
                },
              ),
            ),
            _buildPageIndicator(),
            const SizedBox(height: 10),
            // Character name and description section
            _buildCharacterInfo(),
            const SizedBox(height: 20),
          ],
        ),
      ],
    );
  }

  Widget _buildCharacterItem(int index) {
    // For the first character (index 0), show the user's created character
    if (index == 0) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Display the profile picture if available, otherwise show default icon
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: colorPalette[0].withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: widget.profilePictureUrl.isNotEmpty
                ? ClipOval(
                    child: Image.network(
                      widget.profilePictureUrl,
                      width: 200,
                      height: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        // If image fails to load, show default icon
                        return Center(
                          child: Icon(
                            CupertinoIcons.person_fill,
                            size: 100,
                            color: colorPalette[0],
                          ),
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(colorPalette[0]),
                          ),
                        );
                      },
                    ),
                  )
                : Center(
                    child: Icon(
                      CupertinoIcons.person_fill,
                      size: 100,
                      color: colorPalette[0],
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          _buildRotatingPlatform(),
          const SizedBox(height: 16),
          // Select button right below the image
          ElevatedButton(
            onPressed: () {
              // Handle character selection
              ToastService.showToast(
                context,
                backgroundColor: Theme.of(context).canvasColor,
                shadowColor: Colors.transparent,
                leading: const Icon(
                  FeatherIcons.checkCircle,
                  color: Colors.redAccent,
                ),
                message: 'Selected: ${widget.name}',
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colorPalette[0],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Select'),
          ),
        ],
      );
    }

    // For other characters, show the API data
    final characterData = _characters[index - 1];
    final name = characterData['Name'] ?? 'Unknown';
    final description =
        characterData['Personality'] ?? 'No description available';
    final profilePicture = characterData['ProfilePictureUrl'] ?? '';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: colorPalette[0].withOpacity(0.2),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: profilePicture.isNotEmpty
              ? ClipOval(
                  child: Image.network(
                    profilePicture,
                    width: 200,
                    height: 200,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Icon(
                          CupertinoIcons.person_fill,
                          size: 100,
                          color: colorPalette[0],
                        ),
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(colorPalette[0]),
                        ),
                      );
                    },
                  ),
                )
              : Center(
                  child: Icon(
                    CupertinoIcons.person_fill,
                    size: 100,
                    color: colorPalette[0],
                  ),
                ),
        ),
        const SizedBox(height: 16),
        _buildRotatingPlatform(),
        const SizedBox(height: 16),
        // Select button right below the image
        ElevatedButton(
          onPressed: () {
            // Handle character selection
            ToastService.showToast(
              context,
              backgroundColor: Theme.of(context).canvasColor,
              shadowColor: Colors.transparent,
              leading: const Icon(
                FeatherIcons.checkCircle,
                color: Colors.greenAccent,
              ),
              message: 'Selected: $name',
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: colorPalette[0],
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: const Text('Select'),
        ),
      ],
    );
  }

  Widget _buildCharacterInfo() {
    if (_currentPage == 0) {
      // User's custom character info
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ShaderMask(
              shaderCallback: (bounds) => _currentGradient.createShader(bounds),
              child: Text(
                widget.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.prompt,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    } else if (_characters.isNotEmpty) {
      // API character info
      final characterData = _characters[_currentPage - 1];
      final name = characterData['Name'] ?? 'Unknown';
      final description =
          characterData['Personality'] ?? 'No description available';

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ShaderMask(
              shaderCallback: (bounds) => _currentGradient.createShader(bounds),
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _characters.length + 1, // +1 for user's character
        (index) => Container(
          width: 8.0,
          height: 8.0,
          margin: const EdgeInsets.symmetric(horizontal: 4.0),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _currentPage == index
                ? colorPalette[0]
                : Colors.grey.withOpacity(0.3),
          ),
        ),
      ),
    );
  }

  // Rotating platform similar to 3D model screen
  Widget _buildRotatingPlatform() {
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

  bool _hasValidImageSelection() {
    final candidateImages =
        _generatedCharacter?['candidate_images'] as List<dynamic>? ?? [];
    // If we have candidate images, check if a valid index is selected
    if (candidateImages.isNotEmpty) {
      return _selectedImageIndex >= 0 &&
          _selectedImageIndex < candidateImages.length;
    }
    // If no candidate images, check if we have a profile picture and an image is selected
    final profilePictureUrl = _generatedCharacter?['profilePictureUrl'] ?? '';
    return profilePictureUrl.isNotEmpty && _selectedImageIndex >= 0;
  }
}
