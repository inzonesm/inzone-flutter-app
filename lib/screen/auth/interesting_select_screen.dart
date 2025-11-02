import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:colorful_safe_area/colorful_safe_area.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inzone/components/settings/topic_selector_widget.dart';
import 'package:inzone/components/ui/button.dart';
import 'package:inzone/router/app_router.dart';
import 'package:inzone/router/routes.dart';
import 'package:inzone/services/inzone_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:toasty_box/toast_service.dart';

class InterestSelectionScreen extends StatefulWidget {
  final String email;

  const InterestSelectionScreen({
    super.key,
    required this.email,
  });

  @override
  State<InterestSelectionScreen> createState() =>
      _InterestSelectionScreenState();
}

class _InterestSelectionScreenState extends State<InterestSelectionScreen> {
  final List<String> _interests = [];
  Map<String, List<String>> topicCategories = {};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
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

  void _toggleInterest(String topic) {
    setState(() {
      if (_interests.contains(topic)) {
        _interests.remove(topic);
      } else {
        _interests.add(topic);
      }
    });
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

  Future<void> _finishSignUp() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ToastService.showToast(
        context,
        backgroundColor: Theme.of(context).canvasColor,
        shadowColor: Colors.transparent,
        leading: const Icon(
          Icons
              .error_outline, // or Icons.check_circle, Icons.warning_amber_rounded, etc.
          color: Colors.redAccent, // or Colors.greenAccent, Colors.orange, etc.
        ),
        message: "User not logged in.",
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Center(
            child: Container(
              width: 100, // Adjust as needed
              height: 100, // Adjust as needed
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(100), // Adjust as needed
              ),
              child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(
                    color: Theme.of(context).colorScheme.outline,
                  )),
            ),
          ),
        );
      },
    );
    try {
      print("InterestScreen - Finishing signup for user: ${user.uid}");
      print("InterestScreen - Selected interests: $_interests");

      // Update interests via backend API (this will calculate and set masterCategories)
      final success = await InZoneDatabase.updateUserInterests(user.uid, _interests);
      
      if (!success) {
        throw Exception("Failed to update interests via API");
      }
      
      print("InterestScreen - ✅ Interests and masterCategories updated via API");

      // Set a timestamp to mark profile completion using UTC time
      final timestamp = DateTime.now().toUtc().toIso8601String();
      print("InterestScreen - Setting createdAt timestamp: $timestamp");

      // Update the createdAt timestamp
      await FirebaseFirestore.instance
          .collection('humanUsers')
          .doc(user.uid)
          .update({
        'createdAt': timestamp,
      });

      print("InterestScreen - ✅ Set createdAt timestamp");

      // Force refresh of auth state
      await AppRouter.authNotifier.refreshAuthState();

      if (mounted) {
        Navigator.of(context).pop();

        print("InterestScreen - Navigating to home screen");
        context.pushReplacement(Routes.home);
      }
    } catch (e) {
      if (mounted) {
        context.pop();
      }

      print("InterestScreen - Error completing signup: $e");
      ToastService.showToast(
        context,
        backgroundColor: Theme.of(context).canvasColor,
        shadowColor: Colors.transparent,
        leading: const Icon(
          Icons.error_outline,
          color: Colors.redAccent,
        ),
        message: "Failed to complete sign up: $e",
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColorfulSafeArea(
      color: Theme.of(context).canvasColor,
      child: Scaffold(
        backgroundColor: Theme.of(context).canvasColor,
        body: Column(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Interest',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          'Choose a few topics you care about',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _buildContent(),
            ),
          ],
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
          child: Button(
            text: _interests.isEmpty
                ? "Start InZone"
                : "Start InZone (${_interests.length} selected)",
            onPressed: () {
              if (!_isLoading) {
                _finishSignUp();
              }
            },
          ),
        ),
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
                                          callBack: _toggleInterest,
                                          isSelected: _interests.contains(topic), // Add selection state
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
                                                  callBack: _toggleInterest,
                                                  isSelected: _interests.contains(topic), // Add selection state
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
                                                      callBack: _toggleInterest,
                                                      isSelected: _interests.contains(topic), // Add selection state
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
