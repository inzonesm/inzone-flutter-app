import 'package:flutter/material.dart';
import 'package:inzone/components/avatar_card.dart';
import 'package:inzone/components/category_selector_bar.dart';
import 'package:inzone/components/post_card.dart';
import 'package:inzone/components/repost_card.dart';
import 'package:inzone/data/inzone_avatar.dart';
import 'package:inzone/data/inzone_post.dart';
import 'package:inzone/inzone_database.dart';
import 'package:shimmer/shimmer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller});
  final ScrollController controller;

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  List<Widget> feedItems = [];
  List<Widget> originalFeedItems = []; // Store the original order of feed items
  List<String> categoriesList = [];
  bool isLoading = true;
  bool isLoadingMore = false;
  List<AvatarCard> avatarCards = [];
  late DateTime _startTime;
  int pageOpened = 0;
  int _currentPage = 0;
  final int _pageSize = 20;
  bool hasMorePosts = true;
  String? selectedCategory; // Track the currently selected category
  int reloadCount = 0; // Track number of reloads

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    loadFeed();
    loadAvatars();
    widget.controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    DateTime endTime = DateTime.now();
    Duration timeSpent = endTime.difference(_startTime);
    InZoneDatabase.logEvent('home_screen', {
      "timeSpent": timeSpent.inSeconds,
      "pageOpenedCount": pageOpened,
    });
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (widget.controller.position.pixels >=
            widget.controller.position.maxScrollExtent - 200 &&
        !isLoadingMore &&
        hasMorePosts) {
      _loadMorePosts();
    }
  }

  Future<void> loadAvatars() async {
    try {
      final characters = await InZoneDatabase.getCarouselCharacters();
      if (mounted && characters != null) {
        print("Fetched ${characters.length} characters for carousel");
        _processAvatars(characters);
      }
    } catch (e) {
      print('Error loading avatars: $e');
    }
  }

  Future<void> loadFeed({bool isRefresh = false}) async {
    if (!mounted) return;
    
    if (isRefresh) {
      setState(() {
        _currentPage = 0;
        feedItems.clear();
        originalFeedItems.clear();
        categoriesList.clear();
        avatarCards.clear();
        hasMorePosts = true;
        selectedCategory = null; // Reset selected category on refresh
        reloadCount++; // Increment reload count on refresh
      });
      loadAvatars();
    }

    setState(() {
      isLoading = true;
    });

    try {
      // Fetch data from InZoneDatabase with reload count parameter
      final response = await InZoneDatabase.getFeed(page: reloadCount);
      
      if (!mounted) return;
      
      print("Feed response structure: ${response?.keys.toList()}");
      
      if (response != null) {
        int totalPostsProcessed = 0;
        int skippedRepostsCount = 0;
        
        // Collect all posts from different categories
        List<dynamic> allPosts = [];
        if (response.containsKey('reposts')) {
          List<dynamic> reposts = response['reposts'] ?? [];
          print("Found ${reposts.length} reposts");
          allPosts.addAll(reposts.map((post) => {'type': 'repost', 'data': post}));
          totalPostsProcessed += reposts.length;
        }
        // Add posts from each category to the combined list
        if (response.containsKey('aiPosts')) {
          List<dynamic> aiPosts = response['aiPosts'] ?? [];
          print("Found ${aiPosts.length} AI posts");
          allPosts.addAll(aiPosts.map((post) => {'type': 'ai', 'data': post}));
          totalPostsProcessed += aiPosts.length;
        }
        
        if (response.containsKey('humanPosts')) {
          List<dynamic> humanPosts = response['humanPosts'] ?? [];
          print("Found ${humanPosts.length} human posts");
          allPosts.addAll(humanPosts.map((post) => {'type': 'human', 'data': post}));
          totalPostsProcessed += humanPosts.length;
        }
        

        
        // For backward compatibility, also check for 'posts' key
        if (response.containsKey('posts')) {
          List<dynamic> posts = response['posts'] ?? [];
          print("Found ${posts.length} posts from 'posts' key");
          allPosts.addAll(posts.map((post) => {'type': 'generic', 'data': post}));
          totalPostsProcessed += posts.length;
        }
        
        // Shuffle all posts to mix different types
        allPosts.shuffle();
        print("Shuffled ${allPosts.length} total posts");

        // Process the shuffled posts
        for (var wrappedPost in allPosts) {
          bool wasProcessed = _processPost(wrappedPost['data'], wrappedPost['type']);
          if (!wasProcessed && wrappedPost['type'] == 'repost') {
            skippedRepostsCount++;
          }
        }
        
        print("Total posts processed: $totalPostsProcessed");
        print("Reposts skipped due to empty ai_id: $skippedRepostsCount");
        
        // Store the original order of feed items
        originalFeedItems = List.from(feedItems);
        
        // If no posts were processed at all, we might have reached the end
        if (totalPostsProcessed == 0 && _currentPage > 0) {
          setState(() {
            hasMorePosts = false;
          });
        }
        
        _currentPage++;
      } else {
        print("Feed response was null");
      }
    } catch (e) {
      print('Error loading feed: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMorePosts() async {
    if (isLoadingMore || !mounted) return;
    
    setState(() {
      isLoadingMore = true;
      reloadCount++; // Increment reload count when loading more posts
    });
    
    try {
      final response = await InZoneDatabase.getFeed(page: reloadCount);
      
      if (!mounted) return;
      
      print("Load more response structure: ${response?.keys.toList()}");
      
      if (response != null) {
        int totalNewPosts = 0;
        int skippedRepostsCount = 0;
        
        // Collect all posts from different categories
        List<dynamic> allPosts = [];
        
        // Add posts from each category to the combined list
        if (response.containsKey('aiPosts')) {
          List<dynamic> aiPosts = response['aiPosts'] ?? [];
          print("Loading more: Found ${aiPosts.length} AI posts");
          allPosts.addAll(aiPosts.map((post) => {'type': 'ai', 'data': post}));
          totalNewPosts += aiPosts.length;
        }
        
        if (response.containsKey('humanPosts')) {
          List<dynamic> humanPosts = response['humanPosts'] ?? [];
          print("Loading more: Found ${humanPosts.length} human posts");
          allPosts.addAll(humanPosts.map((post) => {'type': 'human', 'data': post}));
          totalNewPosts += humanPosts.length;
        }
        
        if (response.containsKey('reposts')) {
          List<dynamic> reposts = response['reposts'] ?? [];
          print("Loading more: Found ${reposts.length} reposts");
          allPosts.addAll(reposts.map((post) => {'type': 'repost', 'data': post}));
          totalNewPosts += reposts.length;
        }
        
        // For backward compatibility, also check for 'posts' key
        if (response.containsKey('posts')) {
          List<dynamic> posts = response['posts'] ?? [];
          print("Loading more: Found ${posts.length} posts from 'posts' key");
          allPosts.addAll(posts.map((post) => {'type': 'generic', 'data': post}));
          totalNewPosts += posts.length;
        }
        
        // Shuffle all posts to mix different types
        allPosts.shuffle();
        print("Shuffled ${allPosts.length} total new posts");
        
        // Process the shuffled posts
        for (var wrappedPost in allPosts) {
          bool wasProcessed = _processPost(wrappedPost['data'], wrappedPost['type']);
          if (!wasProcessed && wrappedPost['type'] == 'repost') {
            skippedRepostsCount++;
          }
        }
        
        print("Total new posts loaded: $totalNewPosts");
        print("Reposts skipped due to empty ai_id: $skippedRepostsCount");
        
        // Update the original feed items list
        originalFeedItems = List.from(feedItems);
        
        // If a category is selected, reapply the filter
        if (selectedCategory != null) {
          _filterPostsByCategory(selectedCategory!);
        }
        
        print("Total new posts loaded: $totalNewPosts");
        
        if (totalNewPosts == 0) {
          setState(() {
            hasMorePosts = false;
          });
        } else {
          _currentPage++;
        }
      } else {
        print("Load more response was null");
        setState(() {
          hasMorePosts = false;
        });
      }
    } catch (e) {
      print('Error loading more posts: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoadingMore = false;
        });
      }
    }
  }

  bool _processPost(dynamic postJson, String type) {
    // Process a single post and add to the feed
    Widget postWidget;
    
    try {
      // Check if this is a repost (has AI chat content)
      if (type=='repost') {

        
        // This is a repost
        InZonePost post = InZonePost.fromJsonForHumans(postJson);
        // Override isAi property based on the post type
        post = InZonePost(
          category: post.category,
          userName: post.userName,
          comments: post.comments,
          datePosted: post.datePosted,
          likes: post.likes,
          id: post.id,
          imageContent: post.imageContent,
          videoContent: post.videoContent,
          textContent: post.textContent,
          userReference: post.userReference,
          mainCategory: post.mainCategory,
          isAi: false, // Set isAi based on the post type
        );
        InZoneAvatar avatar = InZoneAvatar.fromRepostJson(postJson);
        postWidget = RepostCard(
          post: post,
          repost: avatar,
          aiChat: postJson["ai_chat_content"] ?? "",
        );

      } else {
        InZonePost post;
        
        if (postJson.containsKey('data')) {
          post = InZonePost.fromJson(postJson);
        } else {
          post = InZonePost.fromJsonForHumans(postJson);
        }
          post = InZonePost(
          category: post.category,
          userName: post.userName,
          comments: post.comments,
          datePosted: post.datePosted,
          likes: post.likes,
          id: post.id,
          imageContent: post.imageContent,
          videoContent: post.videoContent,
          textContent: post.textContent,
          userReference: post.userReference,
          mainCategory: post.mainCategory,
          isAi: type == 'ai', // Set isAi based on the post type
        );
        
        if (type == 'ai') {
          print("Processing AI post: ${post.id}");
          print("AI post details: userName=${post.userName}, isAi=${post.isAi}, userReference=${post.userReference}");
        }
        
        postWidget = PostCard(
          post: post,
          onTap: (postId) {
            print('You tapped on post with ID: $postId');
          },
        );
        
        // Add category if it's new
        if (!categoriesList.contains(post.category) && post.category.isNotEmpty) {
          categoriesList.add(post.category);
        }
      }
      
      // Add to feed items
      print("adding $postWidget");
      feedItems.add(postWidget);
      
      // Insert avatar carousel after 20 posts, and then after every 20 posts
      if ((feedItems.length % 20 == 0) && avatarCards.isNotEmpty) {
        print("Inserting avatar carousel at position ${feedItems.length}");
        feedItems.add(_buildAvatarCarousel());
      }
      
      return true; // Post was processed successfully
    } catch (e) {
      print('Error processing post: $e');
      print('Problematic post: $postJson');
      return false; // Post processing failed
    }
  }

  void _processPosts(List<dynamic> fetchedPosts) {
    // Process each post in the list
    int skippedPosts = 0;
    for (var postJson in fetchedPosts) {
      bool wasProcessed = _processPost(postJson, 'generic'); // Use 'generic' as the default type
      if (!wasProcessed) {
        skippedPosts++;
      }
    }
    if (skippedPosts > 0) {
      print("Skipped $skippedPosts posts during processing");
    }
  }

  void _processAvatars(List<dynamic> fetchedCharacters) {
    avatarCards.clear();
    print("Processing avatars with format: ${fetchedCharacters.runtimeType}");
    try {
      for (var characterData in fetchedCharacters) {
        print("Processing avatar: $characterData");
        
        // Use the new factory method
        InZoneAvatar avatar = InZoneAvatar.fromDirectJson(characterData);
        avatarCards.add(AvatarCard(avatar: avatar));
      }
      print("Successfully processed ${avatarCards.length} avatars");
    } catch (e) {
      print("Error processing avatars: $e");
    }
  }

  // Filter posts by category
  void _filterPostsByCategory(String? category) {
    print("Filtering posts by category: $category");
    
    setState(() {
      selectedCategory = category;
      
      if (category == null) {
        // If no category is selected, restore original order
        feedItems = List.from(originalFeedItems);
        return;
      }
      
      // Create a new list with posts of the selected category at the top
      List<Widget> filteredItems = [];
      List<Widget> otherItems = [];
      
      for (var item in originalFeedItems) {
        if (item is PostCard) {
          String postCategory = item.post.category.toLowerCase();
          String searchCategory = category.toLowerCase();
          
          if (postCategory == searchCategory || 
              postCategory.contains(searchCategory) ||
              searchCategory.contains(postCategory)) {
            print("Found matching post: ${item.post.id} with category $postCategory");
            filteredItems.add(item);
          } else {
            otherItems.add(item);
          }
        } else if (item is RepostCard) {
          String postCategory = item.post.category.toLowerCase();
          String searchCategory = category.toLowerCase();
          
          if (postCategory == searchCategory || 
              postCategory.contains(searchCategory) ||
              searchCategory.contains(postCategory)) {
            print("Found matching repost with category $postCategory");
            filteredItems.add(item);
          } else {
            otherItems.add(item);
          }
        } else {
          // Keep non-post widgets (like avatar carousels) in their original position
          otherItems.add(item);
        }
      }
      
      print("Found ${filteredItems.length} matching posts and ${otherItems.length} other items");
      
      // Combine the filtered items with other items
      feedItems = [...filteredItems, ...otherItems];
    });
  }

  Widget _buildAvatarCarousel() {

    return SizedBox(
      height: 580,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Text(
              "Most Popular",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: avatarCards.map((avatarCard) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: avatarCard,
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        left: false,
        right: false,
        top: false,
        child: RefreshIndicator(
          onRefresh: () async {
            setState(() {
              reloadCount++; // Increment reload count on manual refresh
            });
            await loadFeed(isRefresh: true);
            return;
          },
          child: ListView.builder(
            controller: widget.controller,
            itemCount: isLoading
                ? 2
                : feedItems.length + (isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (isLoading) {
                return index == 0
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 10.0, horizontal: 10),
                        child: buildShimmerCategoryBar(),
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: List.generate(
                              10, (index) => buildShimmerPostCard()),
                        ),
                      );
              } else if (index == 0) {
                // Category bar when not loading
                return categoriesList.isNotEmpty
                    ? Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: CategorySelectorBar(
                          categories: categoriesList,
                          onTap: (selectedCat) {
                            print("Category selected: $selectedCat");
                            _filterPostsByCategory(selectedCat);
                          },
                        ),
                      )
                    : const Text("No categories available");
              } else if (index == feedItems.length && isLoadingMore) {
                return const Center(
                    child: CircularProgressIndicator());
              } else {

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0),
                  child: feedItems[index - 1],
                );
              }
            },
          ),
        ),
      ),
    );
  }

  Widget buildShimmerPostCard() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        height: 100,
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8.0),
        ),
      ),
    );
  }

  Widget buildShimmerCategoryBar() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        height: 50,
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8.0),
        ),
      ),
    );
  }
}
