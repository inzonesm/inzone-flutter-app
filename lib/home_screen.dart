import 'package:flutter/material.dart';
import 'package:inzone/components/avatar_card.dart';
import 'package:inzone/components/category_selector_bar.dart';
import 'package:inzone/components/post_card.dart';


import 'package:flutter/material.dart';
import 'package:inzone/components/repost_card.dart';
import 'package:inzone/data/comment_class.dart';
import 'package:inzone/data/inzone_avatar.dart';
import 'package:inzone/inzone_database.dart';
import 'package:shimmer/shimmer.dart';

import '../data/inzone_post.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<PostCard> posts = [];
  List<String> categoriesList = [];
  List<Widget> finalHomeScreen = [];
  bool isLoading = true;
  List<AvatarCard> avatarCards = [];
  late DateTime _startTime; // To store the start time
int pageOpened = 0;
  getFeed() async {

          setState(() {
            isLoading = true;
          });

          // Clear existing posts and categories before fetching new data
          posts.clear();
          categoriesList.clear();
          avatarCards.clear();

          // Fetch data from InZoneDatabase
          final response = await InZoneDatabase.getFeed();

          // Ensure the response contains the expected structure
          if (response != null && response.containsKey('posts') && response.containsKey('characters')) {
            // Parse the posts from the response
            List<dynamic> fetchedPosts = response['posts'];
            List<dynamic> fetchedCharacters = response['characters'];

            for (var characterJson in fetchedCharacters) {
              InZoneAvatar avatar = InZoneAvatar.fromJson(characterJson);

              avatarCards.add(AvatarCard(avatar: avatar));
            }

            // Process posts
            for (var postJson in fetchedPosts) {
              // Parse the post from the JSON and create the PostCard widget
              InZonePost post = InZonePost.fromJson(postJson);
              posts.add(
                PostCard(
                  post: post,
                  onTap: (postId) {
                    print('You tapped on post with ID: $postId');
                  },
                ),
              );

              // Add unique categories to the list
              if (!categoriesList.contains(post.category) && post.category.isNotEmpty) {
                categoriesList.add(post.category);
              }
            }
            for (int i = 0; i < posts.length; i++){
              if (i%7==0 && i!=0){
                finalHomeScreen.add(    SizedBox(
                  height: 550,  // Adjust height as necessary
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
                        child: Text(
                          "Most Popular",
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),

                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: avatarCards.map((avatarCard) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 1.0),
                                child: avatarCard,
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),);
              }
              finalHomeScreen.add(posts.elementAt(i));
            }
            posts.clear();
            avatarCards.clear();


            setState(() {
              isLoading = false;
            });
          } else {
            // Handle the case when response does not contain the expected structure
            throw Exception('Invalid response structure');
          }

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

  @override
  void initState() {
    getFeed();
    super.initState();
    _startTime = DateTime.now();


  }
@override
  void dispose() {
    // TODO: implement dispose
    DateTime endTime = DateTime.now();
    Duration timeSpent = endTime.difference(_startTime);
    InZoneDatabase.logEvent('home_screen', {"timeSpent" : timeSpent.inSeconds, "pageOpenedCount" : pageOpened});
    super.dispose();
}
  @override
  Widget build(BuildContext context) {

    return Scaffold(

      body: SafeArea(
        left: false,
        right: false,
        child: RefreshIndicator(
          onRefresh: () async {
            await getFeed();
          },
          child:SingleChildScrollView(
            child: ListView.builder(
              physics: const NeverScrollableScrollPhysics(), // Prevents ListView from scrolling (since it's inside SingleChildScrollView)
              shrinkWrap: true, // Ensures ListView takes only as much height as it needs
              itemCount: isLoading ? 2 : 3, // Adjust the item count based on loading states
              itemBuilder: (context, index) {
                if (isLoading) {
                  if (index == 0) {
                    // Shimmer for category bar
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 10),
                      child: buildShimmerCategoryBar(),
                    );
                  } else {
                    // Shimmer for posts
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(children: List.generate(10, (index) => buildShimmerPostCard()),),
                    );
                  }
                } else {
                  if (index == 0) {
                    // Category selector or no categories available
                    return categoriesList.isNotEmpty
                        ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10.0),
                      child: CategorySelectorBar(
                        categories: categoriesList,
                        onTap: (value) {
                          setState(() {
                            finalHomeScreen.sort((a, b) {
                              if (a is PostCard && b is PostCard) {
                                int diffA = (a.post.mainCategory.length - value.length).abs();
                                int diffB = (b.post.mainCategory.length - value.length).abs();
                                return diffA.compareTo(diffB);
                              } else {
                                return 0; // Keep the positions unchanged if a or b is not PostCard
                              }
                            });
                          });
                        },
                      ),
                    )
                        : const Text("No categories available");
                  } else if (index == 1) {
                    // Spacer
                    return const SizedBox(height: 20);
                  } else {
                    // Final home screen posts or no posts available
                    return finalHomeScreen.isNotEmpty
                        ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(children: finalHomeScreen),
                    )
                // ? Padding(
                //   padding: const EdgeInsets.symmetric(horizontal: 16.0),
                //   child: RepostCard(post: InZonePost(category: '', userName: 'aadeshk', comments: <CommentClass>[
                //
                //       ], datePosted: DateTime.now(), likes: 232, imageContent: [], videoContent: [], textContent: 'He just knows me', userReference: 'sdfsdf', mainCategory: '2344', id: '232'), repost: InZoneAvatar(id: '23', name: 'Miles Morales', bio: 'The best animated spiderman', username: '@miles', profilePicture: 'https://images.unsplash.com/photo-1534235947450-6a884353bf9c?q=80&w=2070&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D', personality: 'A fun guy with spidey sense', gender: 'male', subCategory: 'Superheroes', age: 23)),
                // )
                        : const Text("No posts available");
                  }
                }
              },
            ),
          )

        ),
      ),
    );
  }
}
