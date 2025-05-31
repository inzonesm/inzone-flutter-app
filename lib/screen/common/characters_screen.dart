import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inzone/components/posts/shimmering.dart';
import 'dart:math';
import 'package:inzone/data/inzone_avatar.dart';
import 'package:inzone/components/profile/avatar_card.dart';
import 'package:inzone/components/profile/avatar_story_component.dart';
import 'package:inzone/services/inzone_database.dart';
import 'package:inzone/router/routes.dart';
import 'package:inzone/screen/chat/all_chats_screen.dart';
import 'dart:async';

class CharactersScreen extends StatefulWidget {
  const CharactersScreen({super.key});

  @override
  State<CharactersScreen> createState() => _CharactersScreenState();
}

class _CharactersScreenState extends State<CharactersScreen> {
  final List<InZoneAvatar> avatars = [];
  final List<InZoneAvatar> filteredAvatars = [];
  bool isLoading = true;
  String? errorMessage;

  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool isSearching = false;
  String searchQuery = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadCharacters();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadCharacters() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final characters = await InZoneDatabase.getAICharacters(popular: false);

      if (characters != null && mounted) {
        setState(() {
          avatars.clear();
          for (var characterData in characters) {
            InZoneAvatar avatar = InZoneAvatar.fromAICharacter(characterData);
            avatars.add(avatar);
          }
          _filterAvatars(searchQuery);
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Failed to load characters';
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = 'Error: $e';
          isLoading = false;
        });
      }
    }
  }

  void _filterAvatars(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredAvatars.clear();
        filteredAvatars.addAll(avatars);
      } else {
        filteredAvatars.clear();
        filteredAvatars.addAll(avatars.where((avatar) =>
            avatar.name.toLowerCase().contains(query.toLowerCase()) ||
            avatar.bio.toLowerCase().contains(query.toLowerCase()) ||
            avatar.personality.toLowerCase().contains(query.toLowerCase())));
      }
      isSearching = query.isNotEmpty;
    });
  }

  void _onSearchTextChanged(String text) {
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
    }

    _debounce = Timer(const Duration(milliseconds: 500), () {
      _filterAvatars(text);
    });
  }

  void _clearSearch() {
    _searchController.clear();
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
    }
    setState(() {
      searchQuery = '';
      isSearching = false;
    });
    _filterAvatars('');
    _searchFocusNode.unfocus();
  }

  List<Color> _generateUniqueGradient(InZoneAvatar avatar) {
    // Generate a seed from the avatar's ID or name
    final seed = avatar.id.hashCode + avatar.name.hashCode;
    final random = Random(seed);

    final List<List<Color>> gradientOptions = [
      [const Color(0xFF14CFEE), const Color(0xFF2196F3)],
      [const Color(0xFFFF9800), const Color(0xFFFF5722)],
      [const Color(0xFF9C27B0), const Color(0xFFE91E63)],
      [const Color(0xFF4CAF50), const Color(0xFF8BC34A)],
      [const Color(0xFFFF4081), const Color(0xFFD500F9)],
      [const Color(0xFFFFC107), const Color(0xFF9C27B0)],
      [const Color(0xFF00BCD4), const Color(0xFF3F51B5)],
      [const Color(0xFF9C27B0), const Color(0xFF2196F3)],
      [const Color(0xFFFF5722), const Color(0xFFFFEB3B)],
      [const Color(0xFF3F51B5), const Color(0xFF4CAF50)],
    ];

    // Pick a random gradient from the options
    return gradientOptions[random.nextInt(gradientOptions.length)];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Search bar and back button
            Padding(
              padding: const EdgeInsets.only(
                  top: 8.0, left: 8.0, right: 16.0, bottom: 8.0),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: GestureDetector(
                      onTap: () {
                        if (_searchFocusNode.hasFocus) {
                          _searchFocusNode.unfocus();
                          _clearSearch();
                        } else {
                          Navigator.of(context).pop();
                        }
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
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      cursorColor:
                          Theme.of(context).textTheme.bodyMedium?.color,
                      style: Theme.of(context).textTheme.bodyMedium,
                      decoration: InputDecoration(
                        hintText: 'Search characters',
                        hintStyle: TextStyle(
                          color: Theme.of(context).hintColor,
                          fontSize: 14,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 0),
                        suffixIcon: searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: _clearSearch,
                                splashRadius: 16,
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Theme.of(context).cardColor,
                      ),
                      onChanged: (text) {
                        setState(() {
                          searchQuery = text;
                        });
                        _onSearchTextChanged(text);
                      },
                      textInputAction: TextInputAction.search,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    'Characters',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
            // Main content
            Expanded(
              child: _buildContent(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (isLoading) {
      return _buildLoadingGrid(context);
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadCharacters,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (avatars.isEmpty) {
      return const Center(
        child: Text('No characters available'),
      );
    }

    if (isSearching && filteredAvatars.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No characters found for "$searchQuery"',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      );
    }

    // 3-column grid with unlimited rows of circular avatars
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: RefreshIndicator(
        onRefresh: _loadCharacters,
        child: Scrollbar(
          thickness: 6,
          radius: const Radius.circular(10),
          thumbVisibility: true,
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.75,
              crossAxisSpacing: 12,
              mainAxisSpacing: 20,
            ),
            itemCount: isSearching ? filteredAvatars.length : avatars.length,
            itemBuilder: (context, index) {
              return _buildCircularAvatar(
                  isSearching ? filteredAvatars[index] : avatars[index]);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingGrid(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Scrollbar(
        thickness: 6,
        radius: const Radius.circular(10),
        thumbVisibility: true,
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.75,
            crossAxisSpacing: 12,
            mainAxisSpacing: 20,
          ),
          itemCount: 12,
          itemBuilder: (context, index) {
            return _buildCircularLoading(context);
          },
        ),
      ),
    );
  }

  Widget _buildCircularLoading(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                Theme.of(context).cardColor,
                Theme.of(context).cardColor.withOpacity(0.7),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(3.0),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).cardColor,
              ),
              child: Padding(
                padding: const EdgeInsets.all(2.0),
                child: ClipOval(
                  child: SkeletonContainer.circular(
                    width: 105,
                    height: 105,
                    color: Theme.of(context).cardColor.withOpacity(0.7),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SkeletonContainer.rounded(
          width: 80,
          height: 14,
          color: Theme.of(context).cardColor.withOpacity(0.7),
        ),
      ],
    );
  }

  Widget _buildCircularAvatar(InZoneAvatar avatar) {
    List<Color> gradientColors = _generateUniqueGradient(avatar);

    return Column(
      children: [
        Container(
          width: 110, // Larger size
          height: 110, // Larger size
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(3.0), // Border thickness
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: Padding(
                padding: const EdgeInsets.all(2.0), // White padding
                child: ClipOval(
                  child: GestureDetector(
                    onTap: () {
                      // Use the same navigation logic as in AvatarStoryComponent
                      context.push(Routes.chat,
                          extra: ChatUser(
                              name: avatar.name,
                              email: avatar.id,
                              chatId: null,
                              profilePictureURL: avatar.profilePicture));
                    },
                    child: Image.network(
                      avatar.profilePicture,
                      fit: BoxFit.cover,
                      width: 105,
                      height: 105,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[300],
                          child: Center(
                            child: Text(
                              avatar.name.isNotEmpty
                                  ? avatar.name.substring(0, 1).toUpperCase()
                                  : "?",
                              style: const TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Column(
          children: [
            Text(
              avatar.name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ],
    );
  }
}
