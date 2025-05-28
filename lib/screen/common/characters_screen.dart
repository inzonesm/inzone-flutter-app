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

class CharactersScreen extends StatefulWidget {
  const CharactersScreen({super.key});

  @override
  State<CharactersScreen> createState() => _CharactersScreenState();
}

class _CharactersScreenState extends State<CharactersScreen> {
  final List<InZoneAvatar> avatars = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCharacters();
  }

  Future<void> _loadCharacters() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final characters = await InZoneDatabase.getCarouselCharacters();

      if (characters != null && mounted) {
        setState(() {
          avatars.clear();
          for (var characterData in characters) {
            InZoneAvatar avatar = InZoneAvatar.fromDirectJson(characterData);
            avatars.add(avatar);
          }
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
            // Back button row instead of AppBar
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();
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
                  const Expanded(
                    child: Text(
                      'Characters',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 40),
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

    // 3-column grid with unlimited rows of circular avatars
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: RefreshIndicator(
        onRefresh: _loadCharacters,
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.75,
            crossAxisSpacing: 12,
            mainAxisSpacing: 20,
          ),
          itemCount: avatars.length,
          itemBuilder: (context, index) {
            return _buildCircularAvatar(avatars[index]);
          },
        ),
      ),
    );
  }

  // 원형 아바타 로딩 상태를 그리드로 표시
  Widget _buildLoadingGrid(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.75,
          crossAxisSpacing: 12,
          mainAxisSpacing: 20,
        ),
        itemCount: 12, // 로딩 시 표시할 아이템 수
        itemBuilder: (context, index) {
          return _buildCircularLoading(context);
        },
      ),
    );
  }

  // 원형 로딩 아이템
  Widget _buildCircularLoading(BuildContext context) {
    return Column(
      children: [
        // 원형 아바타 로딩 효과
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
        // 이름 로딩 효과
        SkeletonContainer.rounded(
          width: 80,
          height: 14,
          color: Theme.of(context).cardColor.withOpacity(0.7),
        ),
      ],
    );
  }

  Widget _buildCircularAvatar(InZoneAvatar avatar) {
    // 홈페이지와 동일한 방식으로 색상 생성
    List<Color> gradientColors = _generateUniqueGradient(avatar);

    // Custom circular avatar with larger size
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
