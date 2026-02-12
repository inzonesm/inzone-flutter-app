import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:colorful_safe_area/colorful_safe_area.dart';
import 'package:flutter/material.dart';
import 'package:inzone/components/settings/topic_selector_widget.dart';
import 'package:go_router/go_router.dart';
import 'package:inzone/components/ui/button.dart';
import 'package:toasty_box/toast_service.dart';
import 'package:inzone/services/inzone_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ContentSelectionSettingsScreen extends StatefulWidget {
  const ContentSelectionSettingsScreen({super.key});

  @override
  _ContentSelectionSettingsScreenState createState() =>
      _ContentSelectionSettingsScreenState();
}

class _ContentSelectionSettingsScreenState
    extends State<ContentSelectionSettingsScreen> {
  final List<String> selectedTopics = [];
  Map<String, List<String>> topicCategories = {};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    // Load both categories and user interests in parallel
    await Future.wait([
      _fetchCategories(),
      _loadUserInterests(),
    ]);
  }

  Future<void> _loadUserInterests() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('humanUsers')
            .doc(user.uid)
            .get();
        
        if (userDoc.exists) {
          final data = userDoc.data();
          final interests = data?['user_interests'] as List?;
          if (interests != null) {
            setState(() {
              selectedTopics.clear();
              selectedTopics.addAll(List<String>.from(interests));
            });
            print('✅ Loaded ${selectedTopics.length} user interests: $interests');
          } else {
            print('ℹ️  No interests found for user');
          }
        }
      }
    } catch (e) {
      print('❌ Error loading user interests: $e');
    }
  }

  Future<void> _fetchCategories() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final docSnapshot = await FirebaseFirestore.instance
          .collection('content')
          .doc('categories')
          .get();

      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data()!;
        final categories = data['categories'] as Map<String, dynamic>?;

        if (categories != null) {
          // Convert the Firestore data to our expected format
          Map<String, List<String>> convertedCategories = {};
          categories.forEach((key, value) {
            if (value is List) {
              convertedCategories[key] = List<String>.from(value);
            }
          });

          setState(() {
            topicCategories = convertedCategories;
            _isLoading = false;
          });
        } else {
          throw Exception('Categories field not found in document');
        }
      } else {
        throw Exception('Categories document not found');
      }
    } catch (e) {
      print('Error fetching categories: $e');
      setState(() {
        _errorMessage = 'Failed to load categories: $e';
        _isLoading = false;
        // Fallback to empty categories or show error
        topicCategories = {};
      });
    }
  }

  void addToList(String topic) {
    setState(() {
      selectedTopics.contains(topic)
          ? selectedTopics.remove(topic)
          : selectedTopics.add(topic);
    });
  }

  void _saveSelection() async {
    try {
      // Get current user ID
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ToastService.showToast(
          context,
          backgroundColor: Theme.of(context).canvasColor,
          shadowColor: Colors.transparent,
          leading: const Icon(Icons.error, color: Colors.red),
          message: "Error: Not logged in",
        );
        return;
      }

      print('🔍 Saving interests for user: ${user.uid}');
      print('   Selected topics: $selectedTopics');

      // Call the backend to update interests
      final success = await InZoneDatabase.updateUserInterests(user.uid, selectedTopics);
      
      if (success) {
        ToastService.showToast(
          context,
          backgroundColor: Theme.of(context).canvasColor,
          shadowColor: Colors.transparent,
          leading: const Icon(
            Icons.check_circle,
            color: Colors.greenAccent,
          ),
          message: "Interests saved and synced to recommendation engine",
        );
        context.pop();
      } else {
        ToastService.showToast(
          context,
          backgroundColor: Theme.of(context).canvasColor,
          shadowColor: Colors.transparent,
          leading: const Icon(Icons.error, color: Colors.red),
          message: "Failed to save interests",
        );
      }
    } catch (e) {
      print('Error saving interests: $e');
      ToastService.showToast(
        context,
        backgroundColor: Theme.of(context).canvasColor,
        shadowColor: Colors.transparent,
        leading: const Icon(Icons.error, color: Colors.red),
        message: "Error: $e",
      );
    }
  }

  // Fallback icons for categories - we'll extract emoji from category name or use default
  String _getCategoryIcon(String categoryName) {
    // Extract emoji if present at the beginning of the category name
    if (categoryName.isNotEmpty) {
      final runes = categoryName.runes.toList();
      if (runes.isNotEmpty) {
        final firstChar = String.fromCharCode(runes[0]);
        // Check if first character is an emoji (rough check)
        if (firstChar.codeUnitAt(0) > 255) {
          return firstChar;
        }
      }
    }

    // Fallback icon mapping based on keywords in category name
    final lowercaseName = categoryName.toLowerCase();
    if (lowercaseName.contains('art') || lowercaseName.contains('creativity')) {
      return '🎨';
    } else if (lowercaseName.contains('gaming') ||
        lowercaseName.contains('game')) {
      return '🎮';
    } else if (lowercaseName.contains('entertainment') ||
        lowercaseName.contains('meme')) {
      return '🎥';
    } else if (lowercaseName.contains('food') ||
        lowercaseName.contains('diy')) {
      return '👩‍🍳';
    } else if (lowercaseName.contains('pet') ||
        lowercaseName.contains('animal')) {
      return '🐾';
    } else if (lowercaseName.contains('music') ||
        lowercaseName.contains('dance')) {
      return '🎵';
    } else if (lowercaseName.contains('travel') ||
        lowercaseName.contains('adventure')) {
      return '🌍';
    } else if (lowercaseName.contains('health') ||
        lowercaseName.contains('wellness')) {
      return '🧠';
    } else if (lowercaseName.contains('learning') ||
        lowercaseName.contains('education')) {
      return '📚';
    } else if (lowercaseName.contains('environment') ||
        lowercaseName.contains('community')) {
      return '🌱';
    } else {
      return '⭐'; // Default fallback
    }
  }

  void _goBack() {
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return ColorfulSafeArea(
      topColor: Theme.of(context).canvasColor,
      left: false,
      right: false,
      top: true,
      bottom: false,
      child: Scaffold(
        body: Column(
          children: [
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
                        backgroundColor:
                            Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey.shade800
                                : Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.2),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 5),
                          child: Center(
                            child: Icon(
                              Icons.arrow_back_ios,
                              size: 18,
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.grey.shade400
                                  : Colors.blue.shade600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Interest',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 50),
                ],
              ),
            ),
            Expanded(
              child: _buildContent(),
            ),
          ],
        ),
        bottomNavigationBar: Padding(
            padding:
                const EdgeInsets.only(left: 15, right: 15, bottom: 30, top: 15),
            child: Button(
                text: selectedTopics.isEmpty
                    ? "Done"
                    : "Done  (${selectedTopics.length} selected)",
                onPressed: () {
                  if (!_isLoading) {
                    _saveSelection();
                  }
                })),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Loading categories...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Oops! Something went wrong',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: const TextStyle(
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchCategories,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (topicCategories.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.category_outlined,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'No categories available',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchCategories,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  String categoryName = topicCategories.keys.elementAt(index);
                  List<String> topics = topicCategories[categoryName]!;
                  String iconEmoji = _getCategoryIcon(categoryName);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(
                            left: 8.0, top: 16.0, bottom: 8.0),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  iconEmoji,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                // Remove emoji from display name if it exists
                                categoryName.replaceFirst(
                                    RegExp(r'^[\u{1F000}-\u{1F9FF}]\s*',
                                        unicode: true),
                                    ''),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: topics.length <= 4
                            // Single row layout for 4 or fewer topics
                            ? Row(
                                children: topics
                                    .map((topic) => TopicSelectorWidget(
                                          topic: topic,
                                          callBack: addToList,
                                          isSelected: selectedTopics.contains(topic),
                                        ))
                                    .toList(),
                              )
                            // Two-row layout for more than 4 topics
                            : SizedBox(
                                height: 110, // Height for 2 rows of topics
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // First row
                                    Expanded(
                                      child: Row(
                                        children: topics
                                            .sublist(
                                                0,
                                                (topics.length / 2).ceil() >
                                                        topics.length
                                                    ? topics.length
                                                    : (topics.length / 2)
                                                        .ceil())
                                            .map((topic) => TopicSelectorWidget(
                                                  topic: topic,
                                                  callBack: addToList,
                                                  isSelected: selectedTopics.contains(topic),
                                                ))
                                            .toList(),
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    // Second row
                                    Expanded(
                                      child: Row(
                                        children: topics.length >
                                                (topics.length / 2).ceil()
                                            ? topics
                                                .sublist(
                                                    (topics.length / 2).ceil())
                                                .map((topic) =>
                                                    TopicSelectorWidget(
                                                      topic: topic,
                                                      callBack: addToList,
                                                      isSelected: selectedTopics.contains(topic),
                                                    ))
                                                .toList()
                                            : [],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  );
                },
                childCount: topicCategories.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
