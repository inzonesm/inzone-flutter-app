import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:inzone/components/ui/button.dart';

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

class _AICharacterSelectionScreenState
    extends State<AICharacterSelectionScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isLoading = true;

  // Sample character data - in real implementation, this would come from server
  final List<Map<String, String>> _characters = List.generate(
      10,
      (index) => {
            'name': 'AI Character ${index + 1}',
            'description': 'AI assistant with unique personality',
          });

  @override
  void initState() {
    super.initState();
    // Simulate loading from server
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 20, top: 0, bottom: 8),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                    },
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: Theme.of(context).cardColor,
                      foregroundColor: Theme.of(context).cardColor,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 5),
                        child: Center(
                          child: Icon(
                            Icons.arrow_back_ios,
                            size: 18,
                            color:
                                Theme.of(context).textTheme.bodyMedium?.color,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
              ],
            ),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : PageView.builder(
                      controller: _pageController,
                      itemCount: _characters.length,
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
            if (!_isLoading) _buildPageIndicator(),
            const SizedBox(height: 20),
            if (!_isLoading)
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Button(
                  text: 'Select Character',
                  onPressed: () {
                    // Handle character selection
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Selected: ${_characters[_currentPage]['name']}'),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
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
                  color: Colors.black.withOpacity(0.1),
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
                            color: Theme.of(context).colorScheme.primary,
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
                          ),
                        );
                      },
                    ),
                  )
                : Center(
                    child: Icon(
                      CupertinoIcons.person_fill,
                      size: 100,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
          ),
          const SizedBox(height: 20),
          Text(
            widget.name,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              widget.prompt,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      );
    }

    // For other characters, show the sample data
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // In a real implementation, this would be an image from the server
        Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: Icon(
              CupertinoIcons.person_fill,
              size: 100,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          _characters[index]['name'] ?? 'Unknown',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            _characters[index]['description'] ?? '',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ],
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _characters.length,
        (index) => Container(
          width: 8.0,
          height: 8.0,
          margin: const EdgeInsets.symmetric(horizontal: 4.0),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _currentPage == index
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.withOpacity(0.3),
          ),
        ),
      ),
    );
  }
}
