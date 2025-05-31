import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:inzone/components/ui/button.dart';
import 'package:inzone/services/inzone_database.dart';
import 'package:colorful_safe_area/colorful_safe_area.dart';
import 'package:lottie/lottie.dart';
import 'dart:math' as math;
import 'package:go_router/go_router.dart';
import 'package:inzone/router/routes.dart';

class AICharacterSelectionScreen extends StatefulWidget {
  final String name;
  final String prompt;
  final String profilePictureUrl;
  final String characterId;
  const AICharacterSelectionScreen({
    super.key,
    required this.name,
    required this.prompt,
    required this.profilePictureUrl,
    required this.characterId,
  });

  @override
  State<AICharacterSelectionScreen> createState() =>
      _AICharacterSelectionScreenState();
}

class _AICharacterSelectionScreenState extends State<AICharacterSelectionScreen>
    with SingleTickerProviderStateMixin {
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

  // Controller for the character name input
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();

  bool _isGenerating = false;

  // Animation controller for rotating effects
  late AnimationController _rotationController;
  late Animation<double> _rotationAnimation;

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a character description')),
      );
      return;
    }

    // Hide keyboard
    FocusScope.of(context).unfocus();

    setState(() {
      _isGenerating = true;
      _isLoading = true; // Show loading state
    });

    try {
      // Call the API to create popular character
      final result = await InZoneDatabase.createPopularCharacter(
        greeting: "Hello! I'm a new character. Let's chat!",
        name: "AI Character", // Default name
        personality: _promptController.text.trim(),
        numberOfChats: 0,
        profilePictureUrl: "", // Empty for now
        votes: 0,
        createdByHuman: true,
      );

      // Output result (for debugging)
      print("PPPPPPPPPPPP$result");

      if (result["success"] == true && mounted) {
        // // Success - character created
        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(
        //     content: Text('Character created successfully!'),
        //     backgroundColor: Colors.green,
        //   ),
        // );

        setState(() {
          _isLoading = false;
          _isGenerating = false;

          // Save generated character info - using the same field names as before
          _generatedCharacter = {
            'Name': result["data"]["Name"] ?? "AI Character",
            'Personality': _promptController.text.trim(),
            'profilePictureUrl': result["data"]["profile_picture_url"] ?? "",
            'PopularCharacterId': result["data"]["PopularCharacterId"] ?? "",
          };

          // Clear input field
          _promptController.clear();
        });
      } else {
        // Error - show error message
        if (mounted) {
          String errorMessage = result["error"] ?? "Failed to create character";
          setState(() {
            _errorMessage = 'Error: $errorMessage';
            _isGenerating = false;
            _isLoading = false;
          });

          // Display error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $errorMessage'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error: $e';
          _isGenerating = false;
          _isLoading = false;
        });

        // Display exception message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unexpected error: $e'),
            backgroundColor: Colors.red,
          ),
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
              'AI Character Selection',
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
          child: _selectedImageIndex >= 0 && _generatedCharacter != null
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
                Icons.person,
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
              'Create Your AI Character',
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
              'Type a detailed description below to generate a unique AI character',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ),
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
            onPressed: _generateCharacter,
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

    // Initialize name controller
    if (_nameController.text.isEmpty) {
      _nameController.text = name;
    }

    // Array of images to display multiple poses (actually using the same image)
    final List<String> characterImages = [
      profilePictureUrl,
      profilePictureUrl,
      profilePictureUrl,
    ];

    // Debug image URL
    print("Image URL: $profilePictureUrl");

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
                color: colorPalette[0].withOpacity(0.3),
                width: 1,
              ),
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

          const SizedBox(height: 60), // Space for bottom sheet
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

    return ElevatedButton(
      onPressed: () {
        // Handle character selection
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Selected character: $name'),
            backgroundColor: Colors.green,
          ),
        );

        // Add selection post-processing logic here (e.g., navigating to next screen)
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
    return Column(
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
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.transparent
                      : colorPalette[0].withOpacity(0.1),
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
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
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
                child: _isGenerating
                    ? Center(
                        child: SizedBox(
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
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(
                          Icons.arrow_upward_rounded,
                          size: 20,
                          color: Colors.white,
                        ),
                        onPressed: _generateCharacter,
                      ),
              ),
              const SizedBox(width: 10),
            ],
          ),
        ),
      ],
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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Selected: ${widget.name}'),
                ),
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Selected: $name'),
              ),
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
}
