import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:inzone/data/inzone_post.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inzone/services/appsflyer_service.dart';
import 'dart:async'; // Add Timer import
import 'package:cloud_firestore/cloud_firestore.dart';

import '../main.dart';

class InZoneDatabase {
  // Track last API call time to prevent too many requests
  static DateTime? _lastFeedApiCallTime;
  static const _minTimeBetweenCalls = Duration(milliseconds: 500);

  static Future<dynamic> getFeed({int? page}) async {
    // Throttle API requests to prevent overloading
    if (_lastFeedApiCallTime != null) {
      final timeSinceLastCall =
          DateTime.now().toUtc().difference(_lastFeedApiCallTime!);
      if (timeSinceLastCall < _minTimeBetweenCalls) {
        // Wait for the minimum time between calls
        await Future.delayed(_minTimeBetweenCalls - timeSinceLastCall);
      }
    }

    // Update the last API call time
    _lastFeedApiCallTime = DateTime.now().toUtc();

    String url =
        'https://inzoneapi-912424781531.us-central1.run.app/feed/posts-flow';

    // If page parameter is provided, add it to the URL
    if (page != null) {
      if (page != 0) {
        url =
            '$url?user_id=${FirebaseAuth.instance.currentUser!.uid}&page=$page';
      } else {
        url = '$url?user_id=${FirebaseAuth.instance.currentUser!.uid}&page=1';
      }
    }

    try {
      // Make the GET request with timeout
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15), onTimeout: () {
        // Return a timeout response
        throw TimeoutException('The request took too long to complete');
      });

      // Check if the response status code is 200 (OK)
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);

        // Return the response as is - it should contain a 'posts' field with post_type
        return jsonData;
      } else if (response.statusCode == 429) {
        // Too many requests - add additional delay
        print('Rate limited by API (429). Waiting before retrying...');
        await Future.delayed(const Duration(seconds: 2));
        return null;
      } else {
        // Log if status code is not 200 (OK)
        print('API error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      // Handle any other exceptions
      print('Feed API request failed: $e');
      return null;
    }
  }

//   static Future<Map<String, dynamic>?> getHumanFeed() async {
//     String url =
//         'https://us-central1-inzonebackend.cloudfunctions.net/api/feed/getHumanPosts';
//
//     try {
//       // Make the POST request
//       final response = await http.post(
//         Uri.parse(url),
//         headers: {
//           'Content-Type': 'application/json',
//           'Accept': 'application/json',
//         },
//       );
// print(response.body);
//       // Check if the response status code is 200 (OK)
//       if (response.statusCode == 200) {
//         // Decode the response body
//         final Map<String, dynamic> jsonMap = jsonDecode(response.body);
//
//         // Ensure the expected data structure is valid
//         // Return the decoded JSON map
//         return jsonMap;
//             } else {
//         // Log if status code is not 200 (OK)
//         print('Failed to load posts. Status code: ${response.statusCode}');
//         return null;
//       }
//     } catch (e) {
//       // Handle any other exceptions
//       print('Error occurred: $e');
//       return null;
//     }
//   }

  static Future<String?> getCurrentUserUid() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        // Try to refresh the token to make sure it's still valid
        try {
          // await user.reload();
          // Get a fresh token
          // await user.getIdToken(true);
          // Return the UID of the logged-in user
          return user.uid;
        } catch (e) {
          // If token refresh fails, log and return null
          print('Error refreshing user authentication: $e');
          return null;
        }
      } else {
        // User is not signed in
        return null;
      }
    } catch (e) {
      print('Error in getCurrentUserUid: $e');
      return null;
    }
  }

  static Future<String?> sendMessageToAI(String userMessage, String aiUsername,
      String? chatID, List<Set> chatHistory) async {
    String? currentUserUID = await InZoneDatabase.getCurrentUserUid();
    if (currentUserUID == null) {
      // Not logged in, so can't send message.
      return null;
    }

    String? personality;
    String apiAiId = aiUsername; // Default to the ID passed in

    String url =
        'https://ai-apis-912424781531.us-east1.run.app/chat/popularCharacter';

    // Convert each Set to a List (or call toJson() if it's a custom object)
    final chatHistoryJson = chatHistory.map((s) => s.toList()).toList();

    print("Sending message to popularCharacter: $aiUsername");

    try {
      Map<String, dynamic> requestBody = {
        'message': userMessage,
        'ai_id': apiAiId, // Use the fetched name here
        'user_id': currentUserUID,
        'chat_history': chatHistoryJson,
      };
      print("Sending this: $requestBody");

      if (chatID != null) {
        requestBody['ConversationId'] = chatID;
      }

      // Make the POST request
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );
      // Check if the request was successful
      if (response.statusCode == 200) {
        // Decode the response body as JSON
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);

        // Check if the response has the expected structure
        if (jsonResponse.containsKey('data')) {
          return jsonResponse['data']['message'];
        }
        print('Unexpected response format from server');
        return null;
      } else {
        // Return an error message if status code is not 200
        print('Failed to send message. Status code: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error occurred: $e');
      return null;
    }
  }

  static Future<String?> startConversation(String aiUsername) async {
    // String url =
    //     'https://us-central1-inzonebackend.cloudfunctions.net/api/ai/chat';
    String url =
        'https://inzoneapi-912424781531.us-central1.run.app/api/ai/chat';

    String? currentUserUID;
    await InZoneDatabase.getCurrentUserUid().then((value) {
      if (value != null) {
        currentUserUID = value;
      }
    });
    if (currentUserUID != null) {
      try {
        // Create the request body
        Map<String, String> requestBody = {
          'aiUid': aiUsername,
          'userUid': currentUserUID!,
          'userMessage': "Hey"
        };

        // Make the POST request
        final response = await http.post(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode(requestBody), // Encode request body to JSON
        );

        // Check if the request was successful
        if (response.statusCode == 200) {
          // Decode the response body as JSON
          final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
          // Return the 'response' field if it exists in the JSON
          if (jsonResponse.containsKey('response')) {
            return jsonResponse['response'];
          } else {
            return 'Response field not found in the server response';
          }
        } else {
          // Return an error message if status code is not 200
          return 'Failed to send message. Status code: ${response.statusCode}';
        }
      } catch (e) {
        return 'Error occurred: $e';
      }
    }
    return null;
  }

  static Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    const String url =
        'https://inzoneapi-912424781531.us-central1.run.app/user/get-profile';
    String? currentUserUID;
    await InZoneDatabase.getCurrentUserUid().then((value) {
      if (value != null) {
        currentUserUID = value;
      }
    });

    if (currentUserUID == null) {
      return null;
    }

    try {
      // Create URL with query parameter
      final Uri uri = Uri.parse('$url?uid=$currentUserUID');

      // Make the GET request
      final http.Response response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      // Check if the request was successful (status code 200-299)
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        // Check if the response has the expected structure
        if (responseData.containsKey("success") &&
            responseData["success"] == true) {
          // Return the normalized user data from the "data" field
          Map<String, dynamic> userData =
              responseData["data"] as Map<String, dynamic>;
          return normalizeUserProfile(userData);
        } else {
          return null;
        }
      } else {
        // Handle unsuccessful requests here
        return null;
      }
    } catch (e) {
      // Handle any exceptions (network issues, parsing errors, etc.)
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getUserProfile(String userID) async {
    const String baseUrl =
        'https://inzoneapi-912424781531.us-central1.run.app/user/get-profile';

    try {
      // Create URL with query parameter
      final Uri uri = Uri.parse('$baseUrl?uid=$userID');

      // Make the GET request
      final http.Response response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      // Check if the request was successful (status code 200-299)
      if (response.statusCode == 200) {
        // Parse the response body
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        // Check if the response has the expected structure
        if (responseData.containsKey("success") &&
            responseData["success"] == true) {
          // Return the normalized user data from the "data" field
          Map<String, dynamic> userData =
              responseData["data"] as Map<String, dynamic>;
          print("SDSDSDSDSDSDSDSDSD");
          print(userData);
          return normalizeUserProfile(userData);
        } else {
          return null;
        }
      } else {
        // Handle unsuccessful requests here
        return null;
      }
    } catch (e) {
      // Handle any exceptions (network issues, parsing errors, etc.)
      return null;
    }
  }

  // Normalizes user profile data to ensure both lowercase and uppercase fields exist
  static Map<String, dynamic> normalizeUserProfile(
      Map<String, dynamic> profile) {
    Map<String, dynamic> normalizedProfile = {};

    // Only include keys that are present in the sample profile
    if (profile.containsKey('balance')) {
      normalizedProfile['balance'] = profile['balance'];
    }
    if (profile.containsKey('bio')) {
      normalizedProfile['bio'] = profile['bio'];
    }
    if (profile.containsKey('createdAt')) {
      normalizedProfile['createdAt'] = profile['createdAt'];
    }
    if (profile.containsKey('email')) {
      normalizedProfile['email'] = profile['email'];
    }
    if (profile.containsKey('interests')) {
      normalizedProfile['interests'] = profile['interests'];
    }
    if (profile.containsKey('name')) {
      normalizedProfile['name'] = profile['name'];
    }
    if (profile.containsKey('profilePicture')) {
      normalizedProfile['profilePicture'] = profile['profilePicture'];
    }
    if (profile.containsKey('profile_picture_url')) {
      normalizedProfile['profile_picture_url'] = profile['profile_picture_url'];
    }
    if (profile.containsKey('referral_code')) {
      normalizedProfile['referral_code'] = profile['referral_code'];
    }
    if (profile.containsKey('referral_count')) {
      normalizedProfile['referral_count'] = profile['referral_count'];
    }
    if (profile.containsKey('total_referral_earnings')) {
      normalizedProfile['total_referral_earnings'] =
          profile['total_referral_earnings'];
    }
    if (profile.containsKey('uid')) {
      normalizedProfile['uid'] = profile['uid'];
    }
    if (profile.containsKey('username')) {
      normalizedProfile['username'] = profile['username'];
    }

    return normalizedProfile;
  }

  static Future<List<Map<String, dynamic>>?> getFollowers(
      String userUid) async {
    final url = Uri.parse(
        'https://inzoneapi-912424781531.us-central1.run.app/user/get-followers');

    try {
      final response = await http.post(
        url,
        headers: <String, String>{
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'UserId': userUid,
        }),
      );

      if (response.statusCode == 200) {
        // Parse the response
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        // Extract the followers list
        final List<dynamic> followers = responseData['followers'] ?? [];

        // Convert each follower to a Map<String, dynamic>
        return followers.map<Map<String, dynamic>>((follower) {
          if (follower is Map<String, dynamic>) {
            return follower;
          } else {
            // If follower is just a string (ID), create a map with the ID
            return {'id': follower.toString()};
          }
        }).toList();
      } else {
        // Handle errors
        return [];
      }
    } catch (error) {
      return [];
    }
  }

  static Future<void> followUser(
      String followedUid, String followedUserName) async {
    final url = Uri.parse(
        'https://inzoneapi-912424781531.us-central1.run.app/user/follow');

    final headers = {"Content-Type": "application/json"};
    String? currentUserUID;
    String? currentUserName;
    await InZoneDatabase.getCurrentUserUid().then((value) {
      if (value != null) {
        currentUserUID = value;
      }
    });

    // Get current user's name from Firebase Auth
    currentUserName = FirebaseAuth.instance.currentUser?.displayName;

    // Updated to match the new API parameter names and include types
    final body = jsonEncode({
      "FollowerId": currentUserUID,
      "FollowingId": followedUid,
      "FollowerType": "human",
      "FollowingType": "human",
      "FollowerUserName": currentUserName,
      "FollowingUserName": followedUserName
    });

    try {
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode != 200) {}
    } catch (e) {}
  }

  static Future<void> unfollowUser(String followedUid) async {
    final url = Uri.parse(
        'https://inzoneapi-912424781531.us-central1.run.app/user/unfollow');

    final headers = {"Content-Type": "application/json"};
    String? currentUserUID;
    String? currentUserName;
    await InZoneDatabase.getCurrentUserUid().then((value) {
      if (value != null) {
        currentUserUID = value;
      }
    });

    // Get current user's name from Firebase Auth
    currentUserName = FirebaseAuth.instance.currentUser?.displayName;

    // Using the same parameter names as the follow function
    final body = jsonEncode({
      "FollowerId": currentUserUID,
      "FollowingId": followedUid,
      "FollowerType": "human",
      "FollowingType": "human",
      "FollowerUserName": currentUserName,
    });

    try {
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode != 200) {}
    } catch (e) {}
  }

  static Future<List<dynamic>?> getConversations() async {
    String url =
        'https://us-central1-inzonebackend.cloudfunctions.net/api/ai/get-conversations';
    String? userID = await InZoneDatabase.getCurrentUserUid();
    if (userID != null) {
      try {
        // Create the request body
        Map<String, String> requestBody = {
          'userUid': userID,
        };

        // Make the POST request
        final response = await http.post(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode(requestBody), // Encode request body to JSON
        );
        // Check if the request was successful
        if (response.statusCode == 200) {
          // Parse the response body as JSON
          var responseBody = jsonDecode(response.body);

          // Return the value of the key conversationIds
          return responseBody['conversationIds'];
        }
      } catch (e) {
        // Handle errors and return the error message
      }
    }
    return null;
  }

  // Analyze sentiment of text content
  static Future<Map<String, dynamic>> analyzeSentiment(String content) async {
    try {
      var sentimentResponse = await sendSentimentRequest(content);
      if (sentimentResponse != null) {
        int sentiment = sentimentResponse["sentiment"] as int;
        String rawCategory = sentimentResponse["category"] as String;

        // Format category
        if (rawCategory.contains("-")) {
          List<String> parts = rawCategory.split('-');
          rawCategory = parts
              .map((part) => part[0].toUpperCase() + part.substring(1))
              .join(" ");
        }

        // Capitalize first letter
        String category = rawCategory.isNotEmpty
            ? rawCategory[0].toUpperCase() + rawCategory.substring(1)
            : "Entertainment";

        return {
          "sentiment": sentiment,
          "category": category,
        };
      }
      return {"sentiment": -1, "category": "Entertainment"};
    } catch (e) {
      return {"sentiment": -1, "category": "Entertainment"};
    }
  }

  // Create a human post
  static Future<Map<String, dynamic>> createHumanPost({
    required String content,
    required List<String> imageRefs,
    required List<String> videoRefs,
  }) async {
    try {
      // First analyze sentiment
      var analysis = await analyzeSentiment(content);

      // Generate a unique post ID
      String postId =
          "post_${FirebaseAuth.instance.currentUser!.uid}_${DateTime.now().toUtc().millisecondsSinceEpoch}";

      // Get user profile to get the username
      var userProfile = await getCurrentUserProfile();
      String username = "Unknown";

      if (userProfile != null) {
        // Try to get username from profile
        username = userProfile['username'] ?? userProfile['name'] ?? "Unknown";
      }

      // If still unknown, try Firebase Auth displayName as fallback
      if (username == "Unknown" &&
          FirebaseAuth.instance.currentUser?.displayName != null) {
        username = FirebaseAuth.instance.currentUser!.displayName!;
      }

      String url =
          'https://inzoneapi-912424781531.us-central1.run.app/feed/create-human-post';

      Map<String, dynamic> postData = {
        "UserName": username, // Use the retrieved username instead
        "UserDocumentId": FirebaseAuth.instance.currentUser!.uid,
        "Category": analysis["category"],
        "Id": postId,
        "Post": {
          "TextContent": content,
          "ImageContent": imageRefs,
          "VideoContent": videoRefs
        }
      };

      print("Sending post data: $postData");

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(postData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        return {
          "success": true,
          "sentiment": analysis["sentiment"],
          "postId": responseData["postId"],
        };
      } else {
        return {
          "success": false,
          "sentiment": analysis["sentiment"],
          "error": "Failed to create post",
        };
      }
    } catch (e) {
      return {
        "success": false,
        "sentiment": -1,
        "error": e.toString(),
      };
    }
  }

  // Create an AI post
  static Future<Map<String, dynamic>> createAIPost({
    required String content,
    required String aiUsername,
    required List<String> imageRefs,
    required List<String> videoRefs,
  }) async {
    try {
      // First analyze sentiment
      var analysis = await analyzeSentiment(content);

      String url =
          'https://inzoneapi-912424781531.us-central1.run.app/feed/create-ai-post';

      Map<String, dynamic> postData = {
        "UserName": aiUsername,
        "Category": analysis["category"],
        "Post": {
          "TextContent": content,
          "ImageContent": imageRefs,
          "VideoContent": videoRefs
        }
      };

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(postData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        return {
          "success": true,
          "sentiment": analysis["sentiment"],
          "postId": responseData["postId"],
        };
      } else {
        return {
          "success": false,
          "sentiment": analysis["sentiment"],
          "error": "Failed to create post",
        };
      }
    } catch (e) {
      return {
        "success": false,
        "sentiment": -1,
        "error": e.toString(),
      };
    }
  }

  // Create a repost (sharing AI conversation)
  static Future<Map<String, dynamic>> createRepost({
    required String content,
    required String aiName,
    required String aiProfileImageURL,
    required String aiChatContent,
    required String aiId,
    required List<String> imageRefs,
    required List<String> videoRefs,
  }) async {
    try {
      // First analyze sentiment
      var analysis = await analyzeSentiment(content);

      String url =
          'https://inzoneapi-912424781531.us-central1.run.app/feed/create-repost';

      Map<String, dynamic> postData = {
        "UserDocumentId": FirebaseAuth.instance.currentUser!.uid,
        "UserName": FirebaseAuth.instance.currentUser!.displayName,
        "Post": {
          "TextContent": content,
          "ImageContent": imageRefs,
          "VideoContent": videoRefs
        },
        "AIName": aiName,
        "AIProfileImageURL": aiProfileImageURL,
        "AIChatContent": aiChatContent,
        "AiId": aiId
      };

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(postData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        return {
          "success": true,
          "sentiment": analysis["sentiment"],
          "postId": responseData["postId"],
        };
      } else {
        return {
          "success": false,
          "sentiment": analysis["sentiment"],
          "error": "Failed to create repost",
        };
      }
    } catch (e) {
      return {
        "success": false,
        "sentiment": -1,
        "error": e.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>?> sendSentimentRequest(String body) async {
    const String url =
        'https://inzoneapi-912424781531.us-central1.run.app/api/sentiment-analysis';

    try {
      final http.Response response = await http.post(
        Uri.parse(url),
        headers: <String, String>{
          'Content-Type': 'application/json',
        },
        body: json.encode({"text": body}),
      );

      if (response.statusCode == 200) {
        // Decode the JSON response
        Map<String, dynamic> responseData = json.decode(response.body);

        // Check if the response has the expected structure
        if (responseData.containsKey('success') &&
            responseData['success'] == true &&
            responseData.containsKey('data')) {
          // Extract the sentiment data
          Map<String, dynamic> sentimentData = responseData['data'];

          // Validate required keys
          final requiredKeys = [
            "PositiveScore",
            "NegativeScore",
            "NeutralScore",
            "OverallSentiment",
            "Categories",
            "Keywords"
          ];
          if (requiredKeys.every((key) => sentimentData.containsKey(key))) {
            // Get the OverallSentiment value as string
            String overallSentiment =
                sentimentData['OverallSentiment'].toString();
            // Debug print

            // Convert string sentiment to our three categories
            int sentimentCategory;
            switch (overallSentiment.trim().toLowerCase()) {
              case 'positive':
                sentimentCategory = 1;
                break;
              case 'negative':
                sentimentCategory = -1;
                break;
              case 'neutral':
                sentimentCategory = 0;
                break;
              default:
                sentimentCategory = 0; // Default to neutral for unknown values
            }

            return {
              "sentiment": sentimentCategory,
              "category": sentimentData['Categories'].isNotEmpty
                  ? sentimentData['Categories'][0]
                  : "Entertainment"
            };
          } else {
            return null;
          }
        } else if (responseData.containsKey('error')) {
          return null;
        }
        return null;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> createUserProfile(
      {required String name,
      required String email,
      required int age,
      required String userUid,
      required String gender,
      required List<String> userInterests,
      String? bio,
      String? profilePicture,
      String? userName}) async {
    String url =
        "https://inzoneapi-912424781531.us-central1.run.app/user/create-profile";

    // Construct the JSON body with the new parameter names
    final Map<String, dynamic> requestBody = {
      "Name": name,
      "Email": email,
      "Age": age,
      "Gender": gender,
      "UID": userUid,
      "Bio": bio ?? "",
      "ProfilePicture": profilePicture ?? "",
      "UserName": userName ?? name,
      "UserInterests": userInterests
    };

    try {
      // Print the request body for debugging

      final http.Response response = await http.post(
        Uri.parse(url),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        try {
          final Map<String, dynamic> responseData = json.decode(response.body);

          // Check if the response has the expected structure
          if (responseData.containsKey("success") &&
              responseData["success"] == true) {
            return responseData;
          } else {
            return null;
          }
        } catch (e) {
          return null;
        }
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  static Future<void> createCharacter(
      String name, String bio, String profilePictureUrl) async {
    const String url =
        'https://us-central1-inzonebackend.cloudfunctions.net/api/ai/create-character';

    Map<String, String> headers = {"Content-Type": "application/json"};
    Map<String, dynamic> body = {
      "name": name,
      "bio": bio,
      "profilePicture": profilePictureUrl
    };

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        // Handle response here
      } else {}
    } catch (e) {}
  }

  static Future<Map<String, dynamic>> createPopularCharacter({
    required String greeting,
    required String name,
    required String personality,
    int? numberOfChats,
    String? profilePictureUrl,
    int? votes,
    bool? createdByHuman,
    String? creatorId,
  }) async {
    const String url =
        'https://ai-apis-912424781531.us-east1.run.app/create/popularCharacter';

    Map<String, String> headers = {"Content-Type": "application/json"};
    Map<String, dynamic> body = {
      "Greeting": greeting,
      "Name": name,
      "Personality": personality,
    };

    // Add optional fields if provided
    if (numberOfChats != null) body["NumberOfChats"] = numberOfChats;
    if (profilePictureUrl != null)
      body["ProfilePictureUrl"] = profilePictureUrl;
    if (votes != null) body["Votes"] = votes;
    if (createdByHuman != null) body["CreatedByHuman"] = createdByHuman;
    if (creatorId != null) body["CreatorId"] = creatorId;

    print("Creating popular character with body: ${jsonEncode(body)}");

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(body),
      );

      final Map<String, dynamic> responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          "success": true,
          "data": responseData,
        };
      } else {
        return {
          "success": false,
          "error": responseData["error"] ?? "Unknown error",
          "code": responseData["code"] ?? "UNKNOWN_ERROR",
        };
      }
    } catch (e) {
      return {
        "success": false,
        "error": "Network error: $e",
        "code": "NETWORK_ERROR",
      };
    }
  }

  Future<Map<String, String>?> generate3DAvatar(String prompt) async {
    final url = Uri.parse(
        'https://inzoneapi-912424781531.us-central1.run.app/api/full_generate');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'prompt': prompt}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'model_url': data['model_url'],
          'texture_url': data['texture_url'],
        };
      } else {
        print("Error: ${response.body}");
        return null;
      }
    } catch (e) {
      print("Exception: $e");
      return null;
    }
  }

  static Future<String?> generateImage(String imagePrompt) async {
    const String url =
        'https://inzoneapi-912424781531.us-central1.run.app/api/ai/generate-image';

    Map<String, String> headers = {"Content-Type": "application/json"};
    Map<String, dynamic> body = {"imagePrompt": imagePrompt};

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        // Parse the response according to the expected structure
        Map<String, dynamic> jsonResponse = jsonDecode(response.body);

        // Check if the response has the success field and it's true
        if (jsonResponse.containsKey("success") &&
            jsonResponse["success"] == true) {
          // Check if the data field exists and contains the image URL
          if (jsonResponse.containsKey("data") &&
              jsonResponse["data"] is Map<String, dynamic> &&
              jsonResponse["data"].containsKey("imageUrl")) {
            return jsonResponse["data"]["imageUrl"];
          }
        }

        return null;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  static Future<bool?> logEvent(String eventName, Map? eventValues) async {
    bool? result;
    try {
      final appsFlyerService = AppsFlyerService();

      final safeEventValues =
          eventValues == null ? null : Map<String, dynamic>.from(eventValues);

      result = await appsFlyerService.logEvent(eventName, safeEventValues);
      return result;
    } on Exception catch (e) {
      // Handle any exceptions that occur during the logging process
      print('Error logging event: $e');
    } catch (e) {
      // Handle any other exceptions
      print('Unexpected error: $e');
    }
    return null;
  }

  static Future<bool> updateUserProfile({
    required String userId,
    String? username,
    String? bio,
    String? profilePicture,
    String? name,
  }) async {
    try {
      // Verify authentication status
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('Error: Not authenticated');
        return false;
      }

      bool allSuccessful = true;
      List<Future<bool>> updateRequests = [];

      // Update name if provided
      if (name != null) {
        updateRequests.add(updateUserName(userId, name));
      }

      // Update username if provided
      if (username != null) {
        updateRequests.add(updateUserUsername(userId, username));
      }

      // Update bio if provided
      if (bio != null) {
        updateRequests.add(updateUserBio(userId, bio));
      }

      // Update profile picture if provided
      if (profilePicture != null) {
        updateRequests.add(updateUserProfilePicture(userId, profilePicture));
      }

      // Wait for all requests to complete
      final results = await Future.wait(updateRequests);

      // Check if any request failed
      for (bool result in results) {
        if (!result) {
          allSuccessful = false;
          break;
        }
      }

      return allSuccessful;
    } catch (e) {
      print('Error in updateUserProfile: $e');
      return false;
    }
  }

  // Helper method to update user name
  static Future<bool> updateUserName(String userId, String name) async {
    const String url =
        'https://inzoneapi-912424781531.us-central1.run.app/user/update-name';

    Map<String, dynamic> requestBody = {
      "UID": userId,
      "Name": name,
    };

    try {
      final http.Response response = await http.post(
        Uri.parse(url),
        headers: <String, String>{
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        return responseData["success"] == true;
      } else {
        print('Failed to update name. Status code: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Error updating name: $e');
      return false;
    }
  }

  // Helper method to update username
  static Future<bool> updateUserUsername(String userId, String username) async {
    const String url =
        'https://inzoneapi-912424781531.us-central1.run.app/user/update-username';

    Map<String, dynamic> requestBody = {
      "UID": userId,
      "Username": username,
    };

    try {
      final http.Response response = await http.post(
        Uri.parse(url),
        headers: <String, String>{
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        FirebaseAuth.instance.currentUser?.updateProfile(displayName: username);
        return responseData["success"] == true;
      } else {
        print('Failed to update username. Status code: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Error updating username: $e');
      return false;
    }
  }

  // Helper method to update bio
  static Future<bool> updateUserBio(String userId, String bio) async {
    const String url =
        'https://inzoneapi-912424781531.us-central1.run.app/user/update-bio';

    Map<String, dynamic> requestBody = {
      "UID": userId,
      "Bio": bio,
    };

    try {
      final http.Response response = await http.post(
        Uri.parse(url),
        headers: <String, String>{
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        return responseData["success"] == true;
      } else {
        print('Failed to update bio. Status code: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Error updating bio: $e');
      return false;
    }
  }

  // Helper method to update profile picture
  static Future<bool> updateUserProfilePicture(
      String userId, String profilePicture) async {
    const String url =
        'https://inzoneapi-912424781531.us-central1.run.app/user/update-profile-picture';

    Map<String, dynamic> requestBody = {
      "UID": userId,
      "ProfilePicture": profilePicture,
    };

    try {
      final http.Response response = await http.post(
        Uri.parse(url),
        headers: <String, String>{
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        return responseData["success"] == true;
      } else {
        print(
            'Failed to update profile picture. Status code: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Error updating profile picture: $e');
      return false;
    }
  }

  static Future<bool> updatePost({
    required String postId,
    String? content,
    String? imageUrl,
  }) async {
    const String url =
        'https://inzoneapi-912424781531.us-central1.run.app/feed/update-post';

    // Build the request body with the required postId
    Map<String, dynamic> requestBody = {
      "PostId": postId,
    };

    // Add optional fields if they are provided
    if (content != null) requestBody["Content"] = content;
    if (imageUrl != null) requestBody["ImageUrl"] = imageUrl;

    try {
      final http.Response response = await http.post(
        Uri.parse(url),
        headers: <String, String>{
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        // Check if the update was successful
        if (responseData.containsKey("success") &&
            responseData["success"] == true) {
          return true;
        } else {
          return false;
        }
      } else if (response.statusCode == 404) {
        return false;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  static Future<String?> writeComment({
    required String postId,
    required String content,
  }) async {
    const String url =
        'https://inzoneapi-912424781531.us-central1.run.app/feed/write-comment';

    String? currentUserUID;
    await InZoneDatabase.getCurrentUserUid().then((value) {
      if (value != null) {
        currentUserUID = value;
      }
    });

    if (currentUserUID == null) {
      return null;
    }

    // Build the request body
    Map<String, dynamic> requestBody = {
      "PostId": postId,
      "UserId": currentUserUID,
      "Content": content,
    };

    try {
      final http.Response response = await http.post(
        Uri.parse(url),
        headers: <String, String>{
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        // Check if the response contains the comment ID
        if (responseData.containsKey("commentId")) {
          return responseData["commentId"];
        } else {
          return null;
        }
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  static Future<bool> likePost(String postId) async {
    const String url =
        'https://inzoneapi-912424781531.us-central1.run.app/user/like-post';

    String? currentUserUID;
    await InZoneDatabase.getCurrentUserUid().then((value) {
      if (value != null) {
        currentUserUID = value;
      }
    });

    if (currentUserUID == null) {
      return false;
    }

    // Build the request body
    Map<String, dynamic> requestBody = {
      "PostId": postId,
      "UserId": currentUserUID,
    };

    try {
      final http.Response response = await http.post(
        Uri.parse(url),
        headers: <String, String>{
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        // Check if the operation was successful
        if (responseData.containsKey("success") &&
            responseData["success"] == true) {
          return true;
        } else {
          return false;
        }
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  static Future<bool> unlikePost(String postId) async {
    const String url =
        'https://inzoneapi-912424781531.us-central1.run.app/user/unlike-post';

    String? currentUserUID;
    await InZoneDatabase.getCurrentUserUid().then((value) {
      if (value != null) {
        currentUserUID = value;
      }
    });

    if (currentUserUID == null) {
      return false;
    }

    // Build the request body
    Map<String, dynamic> requestBody = {
      "PostId": postId,
      "UserId": currentUserUID,
    };

    try {
      final http.Response response = await http.post(
        Uri.parse(url),
        headers: <String, String>{
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        // Check if the operation was successful
        if (responseData.containsKey("success") &&
            responseData["success"] == true) {
          return true;
        } else {
          return false;
        }
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  static Future<bool> removeFromFollowing(String followingId) async {
    const String url =
        'https://inzoneapi-912424781531.us-central1.run.app/user/remove-from-following';

    String? currentUserUID;
    await InZoneDatabase.getCurrentUserUid().then((value) {
      if (value != null) {
        currentUserUID = value;
      }
    });

    if (currentUserUID == null) {
      return false;
    }

    // Build the request body
    Map<String, dynamic> requestBody = {
      "FollowerId": currentUserUID, // Current user (who is following)
      "FollowingId": followingId, // User to unfollow
    };

    try {
      final http.Response response = await http.post(
        Uri.parse(url),
        headers: <String, String>{
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  static Future<bool> removeFromFollowers(String followerId) async {
    const String url =
        'https://inzoneapi-912424781531.us-central1.run.app/user/remove-from-followers';

    String? currentUserUID;
    await InZoneDatabase.getCurrentUserUid().then((value) {
      if (value != null) {
        currentUserUID = value;
      }
    });

    if (currentUserUID == null) {
      return false;
    }

    // Build the request body
    Map<String, dynamic> requestBody = {
      "FollowerId": currentUserUID, // Current user (who is being followed)
      "FollowingId": followerId, // User to remove as follower
    };

    try {
      final http.Response response = await http.post(
        Uri.parse(url),
        headers: <String, String>{
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>?> getCarouselCharacters() async {
    const String url =
        'https://inzoneapi-912424781531.us-central1.run.app/api/ai/carousel/characters?showPopularFirst=true';

    try {
      final http.Response response = await http.get(
        Uri.parse(url),
        headers: <String, String>{
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        // Parse the response as a list of characters
        final List<dynamic> responseData = jsonDecode(response.body);

        // Convert the dynamic list to a list of maps
        return responseData
            .map((character) => character as Map<String, dynamic>)
            .toList();
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>?> getAICharacters(
      {bool popular = false}) async {
    final String url =
        'https://ai-apis-912424781531.us-east1.run.app/characters${popular ? "?popular=true" : ""}';

    try {
      final http.Response response = await http.get(
        Uri.parse(url),
        headers: <String, String>{
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        if (responseData['success'] == true &&
            responseData.containsKey('characters')) {
          final List<dynamic> characters = responseData['characters'];
          return characters
              .map((character) => character as Map<String, dynamic>)
              .toList();
        } else {
          return null;
        }
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  static Future<List<dynamic>?> getUserPosts(String userId) async {
    const String url =
        'https://inzoneapi-912424781531.us-central1.run.app/feed/get-user-posts';

    try {
      // Create the request body
      final Map<String, dynamic> requestBody = {
        'UserId': userId,
      };

      // Make the POST request
      final http.Response response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      // Check if the request was successful (status code 200)
      if (response.statusCode == 200) {
        // Parse the response body as a list
        final List<dynamic> rawPosts = jsonDecode(response.body);

        // Print the raw structure of the first post for debugging
        if (rawPosts.isNotEmpty) {}

        return rawPosts; // Return the raw posts directly without transformation
      } else {
        // Handle unsuccessful requests
        return null;
      }
    } catch (e) {
      // Handle any exceptions
      return null;
    }
  }

  static Future<List<dynamic>?> getAIUserPosts(String userId) async {
    const String url =
        'https://inzoneapi-912424781531.us-central1.run.app/feed/get-ai-posts';

    try {
      // Create the request body
      final Map<String, dynamic> requestBody = {
        'UserName': userId,
      };

      // Make the POST request
      final http.Response response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      // Check if the request was successful (status code 200)
      if (response.statusCode == 200) {
        // Parse the response body as a list
        final List<dynamic> rawPosts = jsonDecode(response.body);

        // Print the raw structure of the first post for debugging
        if (rawPosts.isNotEmpty) {}

        return rawPosts; // Return the raw posts directly without transformation
      } else {
        // Handle unsuccessful requests
        return null;
      }
    } catch (e) {
      // Handle any exceptions
      return null;
    }
  }

  // Method to fetch AI user profile
  static Future<Map<String, dynamic>?> getAIUserProfile(String username) async {
    const String url =
        'https://inzoneapi-912424781531.us-central1.run.app/api/ai/get-ai-user';

    try {
      // Create the URL with query parameter
      final Uri uri = Uri.parse('$url?username=$username');

      // Make the GET request
      final http.Response response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      // Check if the request was successful (status code 200)
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        // Check if the response has the expected structure
        if (responseData.containsKey("success") &&
            responseData["success"] == true) {
          // Return the normalized user data from the "data" field
          Map<String, dynamic> userData =
              responseData["data"] as Map<String, dynamic>;
          return normalizeUserProfile(userData);
        } else {
          return null;
        }
      } else {
        // Handle unsuccessful requests
        return null;
      }
    } catch (e) {
      // Handle any exceptions
      return null;
    }
  }

  // Add this method to update user profile
  static Future<void> updateUserProfileData(
      String userId, Map<String, dynamic> profileData) async {
    try {
      // Verify the user is still authenticated
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      List<Future<bool>> updateRequests = [];

      // Send separate update requests for each field
      if (profileData.containsKey('name')) {
        updateRequests.add(updateUserName(userId, profileData['name']));
      }

      if (profileData.containsKey('username')) {
        updateRequests.add(updateUserUsername(userId, profileData['username']));
      }

      if (profileData.containsKey('bio')) {
        updateRequests.add(updateUserBio(userId, profileData['bio']));
      }

      if (profileData.containsKey('profilePicture')) {
        updateRequests.add(
            updateUserProfilePicture(userId, profileData['profilePicture']));
      }

      // Wait for all requests to complete
      final results = await Future.wait(updateRequests);

      // Check if any request failed
      for (bool result in results) {
        if (!result) {
          throw Exception('Failed to update one or more profile fields');
        }
      }

      // Success, all updates completed
      return;
    } catch (e) {
      print('Error in updateUserProfileData: $e');
      rethrow; // Rethrow to handle in UI
    }
  }

  // AI User Follow/Unfollow Functions
  static Future<bool> followAIUser(String aiUserId) async {
    const String url =
        'https://inzoneapi-912424781531.us-central1.run.app/user/follow';

    String? currentUserUID = await getCurrentUserUid();
    String? currentUserName = FirebaseAuth.instance.currentUser?.displayName;

    if (currentUserUID == null) {
      return false;
    }

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'FollowerId': currentUserUID,
          'FollowingId': aiUserId,
          'FollowerType': 'human',
          'FollowingType': 'ai',
          'FollowerUserName': currentUserName,
          'FollowingUserName': aiUserId
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return responseData['success'] ?? false;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  static Future<bool> unfollowAIUser(String aiUserId) async {
    const String url =
        'https://inzoneapi-912424781531.us-central1.run.app/user/unfollow';

    String? currentUserUID = await getCurrentUserUid();
    String? currentUserName = FirebaseAuth.instance.currentUser?.displayName;

    if (currentUserUID == null) {
      return false;
    }

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'FollowerId': currentUserUID,
          'FollowingId': aiUserId,
          'FollowerType': 'human',
          'FollowingType': 'ai',
          'FollowerUserName': currentUserName,
          'FollowingUserName': aiUserId
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return responseData['success'] ?? false;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  static Future<List<String>> getAIFollowers(String userId) async {
    const String url =
        'https://inzoneapi-912424781531.us-central1.run.app/api/ai/get-followers';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'UserId': userId,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final List<dynamic> followers = responseData['followers'] ?? [];
        return followers.map((e) => e.toString()).toList();
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  static Future<List<String>> getAIFollowing(String userId) async {
    const String url =
        'https://inzoneapi-912424781531.us-central1.run.app/api/ai/get-following';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'UserId': userId,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final List<dynamic> following = responseData['following'] ?? [];
        return following.map((e) => e.toString()).toList();
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  static Future<bool> removeFromAIFollowers(String followerId) async {
    const String url =
        'https://inzoneapi-912424781531.us-central1.run.app/api/ai/remove-from-followers';

    String? currentUserUID = await getCurrentUserUid();
    if (currentUserUID == null) {
      return false;
    }

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'UserId': currentUserUID,
          'FollowerId': followerId,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return responseData['success'] ?? false;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  static Future<bool> removeFromAIFollowing(String followingId) async {
    const String url =
        'https://inzoneapi-912424781531.us-central1.run.app/api/ai/remove-from-following';

    String? currentUserUID = await getCurrentUserUid();
    if (currentUserUID == null) {
      return false;
    }

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'UserId': currentUserUID,
          'FollowingId': followingId,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return responseData['success'] ?? false;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }
}

class LikedPostsPreferences {
  static const String likedPostsKey = 'likedPostDetails';

  // Add a post (InZonePost) to the liked posts
  static Future<void> addLikedPost(InZonePost post) async {
    // Validate post ID before proceeding
    if (post.id == "unknown" || post.id.isEmpty) {
      return;
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Retrieve the current liked posts as a map of postId -> post details (as JSON strings)
    Map<String, String> likedPosts = Map<String, String>.from(
        jsonDecode(prefs.getString(likedPostsKey) ?? '{}'));

    // Serialize the InZonePost object into a JSON string
    try {
      Map<String, dynamic> postJsonMap = post.toJson();
      String postJson = jsonEncode(postJsonMap);

      // Add or update the post details in the map using the post ID as the key
      likedPosts[post.id] = postJson;

      // Save the updated liked posts back to SharedPreferences
      await prefs.setString(likedPostsKey, jsonEncode(likedPosts));
    } catch (e) {}
  }

  // Remove a post ID from the liked posts
  static Future<void> removeLikedPost(String postId) async {
    // Validate post ID before proceeding
    if (postId == "unknown" || postId.isEmpty) {
      return;
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Retrieve the current liked posts
    Map<String, String> likedPosts = Map<String, String>.from(
        jsonDecode(prefs.getString(likedPostsKey) ?? '{}'));

    // Remove the post ID if it's in the liked posts
    if (likedPosts.containsKey(postId)) {
      likedPosts.remove(postId);
      await prefs.setString(likedPostsKey, jsonEncode(likedPosts));
    }
  }

  // Get all liked posts (as a list of InZonePost objects)
  static Future<List<InZonePost>> getLikedPosts() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Retrieve the liked posts as a map
    String? rawData = prefs.getString(likedPostsKey);

    if (rawData == null || rawData == '{}') {
      return [];
    }

    try {
      Map<String, dynamic> rawMap = jsonDecode(rawData);

      // Convert the raw map to the expected format
      Map<String, String> likedPosts = {};
      rawMap.forEach((key, value) {
        if (value is String) {
          likedPosts[key] = value;
        } else {
          // If the value is not a string, try to encode it
          likedPosts[key] = jsonEncode(value);
        }
      });

      // Convert the map back into a list of InZonePost objects
      List<InZonePost> posts = [];

      likedPosts.forEach((postId, postJson) {
        try {
          Map<String, dynamic> postMap = jsonDecode(postJson);
          InZonePost post = InZonePost.fromJsonLocal(postMap);
          posts.add(post);
        } catch (e) {}
      });

      return posts;
    } catch (e) {
      return [];
    }
  }

  // Check if a specific post is liked by its ID
  static Future<bool> isPostLiked(String postId) async {
    // Validate post ID before proceeding
    if (postId == "unknown" || postId.isEmpty) {
      return false;
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Retrieve the liked posts
    String? rawData = prefs.getString(likedPostsKey);

    Map<String, String> likedPosts =
        Map<String, String>.from(jsonDecode(rawData ?? '{}'));

    bool isLiked = likedPosts.containsKey(postId);
    return isLiked;
  }

  // Clear all liked posts (for debugging)
  static Future<void> clearAllLikedPosts() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Clear the liked posts by setting an empty map
    await prefs.setString(likedPostsKey, '{}');
  }
}
