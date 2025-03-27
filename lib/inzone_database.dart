import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:inzone/data/inzone_post.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'main.dart';

class InZoneDatabase {
  static Future<dynamic> getFeed({int? page}) async {
    String url =
        'https://inzoneapi-912424781531.us-central1.run.app/feed/posts-flow';

    // If page parameter is provided, add it to the URL
    if (page != null ) {
      print("PAGE");
      print(page);
      if (page!=0){
        url = 'https://inzoneapi-912424781531.us-central1.run.app/feed/posts-flow?page=$page';
      } else {
        url = 'https://inzoneapi-912424781531.us-central1.run.app/feed/posts-flow?page=1';
      }

    }

    try {
      // Make the GET request
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      // Check if the response status code is 200 (OK)
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        print("The feed data is");
        print(jsonData);
        print("Raw response structure: ${jsonData.runtimeType}");
        if (jsonData is Map) {
          print("Response keys: ${jsonData.keys.toList()}");
          if (jsonData.containsKey('aiPosts')) {
            print("AI posts count from server: ${(jsonData['aiPosts'] as List).length}");
          }
        } else if (jsonData is List) {
          print("Response is a list with ${jsonData.length} items");
        }
        
        // Check if the response is already in the expected format with aiPosts, humanPosts, and reposts
        if (jsonData is Map && 
            (jsonData.containsKey('aiPosts') || 
             jsonData.containsKey('humanPosts') || 
             jsonData.containsKey('reposts'))) {
          // The response is already in the expected format, keep it as is
          print("The json data is $jsonData");
          return jsonData;
        } else if (jsonData is List) {
          // The response is a list of posts, try to categorize them
          
          // Create empty lists for each category
          List<dynamic> aiPosts = [];
          List<dynamic> humanPosts = [];
          List<dynamic> reposts = [];
          int emptyAiIdCount = 0;
          
          // Categorize posts based on their properties
          for (var post in jsonData) {
            if (post.containsKey('aiChatContent') || 
                post.containsKey('aiName') || 
                post.containsKey('aiProfileImageURL')) {
              // This is a repost
              
              // Check if ai_id is empty
              if (post.containsKey('ai_id') && (post['ai_id'] == null || post['ai_id'] == "")) {
                print("Found repost with empty ai_id: ${post['id'] ?? 'unknown id'}");
                emptyAiIdCount++;
              }
              
              reposts.add(post);
            } else if (post.containsKey('is_ai') && post['is_ai'] == true) {
              // This is an AI post
              print("Found AI post: ${post['id'] ?? 'unknown id'}");
              aiPosts.add(post);
            } else {
              // This is a human post
              humanPosts.add(post);
            }
          }
          
          print("Total AI posts found: ${aiPosts.length}");
          print("Total reposts found: ${reposts.length}");
          print("Reposts with empty ai_id: $emptyAiIdCount");
          if (aiPosts.isNotEmpty) {
            print("First AI post structure: ${aiPosts[0]}");
          }
          
          return {
            'aiPosts': aiPosts,
            'humanPosts': humanPosts,
            'reposts': reposts
          };
        } else {
          // Unexpected format
          print("Unexpected response format: $jsonData");
          return {
            'aiPosts': [],
            'humanPosts': [],
            'reposts': []
          };
        }
      } else {
        // Log if status code is not 200 (OK)
        print('Failed to load posts. Status code: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      // Handle any other exceptions
      print('Error occurred: $e');
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
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // Return the UID of the logged-in user
      return user.uid;
    } else {
      // User is not signed in, handle accordingly
      return null;
    }
  }

  static Future<String?> sendMessageToAI(
      String userMessage, String aiUsername, String? chatID) async {
    String url;
    if (aiUsername.contains('.')){
       url =
          'https://ai-apis-912424781531.us-east1.run.app/chat/aiUser';
    } else {
      url =
          'https://ai-apis-912424781531.us-east1.run.app/chat/popularCharacter';
    }

    String? currentUserUID;

    await InZoneDatabase.getCurrentUserUid().then((value) {
      if (value != null) {
        currentUserUID = value;
      }
    });
    
    if (currentUserUID != null) {
      try {
        Map<String, String> requestBody = {
          'message': userMessage,
          'ai_id': aiUsername,
        };
        
        // Add conversation ID if it exists
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
          return 'Unexpected response format from server';
        } else {
          // Return an error message if status code is not 200
          return 'Failed to send message. Status code: ${response.body}';
        }
      } catch (e) {
        return 'Error occurred: $e';
      }
    }
    return null;
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
      print(aiUsername);
      print(currentUserUID);
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
          print(jsonResponse);
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
      print(value);
      if (value != null) {
        currentUserUID = value;
      }
    });
    
    if (currentUserUID == null) {
      print('Cannot get profile: User not logged in');
      return null;
    }
    
    print(currentUserUID);
    
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
        print(response.body);
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        
        // Check if the response has the expected structure
        if (responseData.containsKey("success") && responseData["success"] == true) {
          // Return the user data from the "data" field
          return responseData["data"] as Map<String, dynamic>;
        } else {
          print('API returned success: false');
          return null;
        }
      } else {
        // Handle unsuccessful requests here
        print(
            'Failed to load user profile. Status code: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      // Handle any exceptions (network issues, parsing errors, etc.)
      print('Error occurred: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getUserProfile(String userID) async {
    print("Fetching profile for uid $userID");
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
      print("Profile response: ${response.body}");
      if (response.statusCode == 200) {
        // Parse the response body
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        
        // Check if the response has the expected structure
        if (responseData.containsKey("success") && responseData["success"] == true) {
          // Return the user data from the "data" field
          return responseData["data"] as Map<String, dynamic>;
        } else {
          print('API returned success: false - ${responseData["error"] ?? "Unknown error"}');
          return null;
        }
      } else {
        // Handle unsuccessful requests here
        print('Failed to load user profile. Status code: ${response.statusCode}');
        print('Response body: ${response.body}');
        return null;
      }
    } catch (e) {
      // Handle any exceptions (network issues, parsing errors, etc.)
      print('Error fetching user profile: $e');
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>?> getFollowers(String userUid) async {
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
        print('Followers response: $responseData');
        
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
        print('Error: ${response.statusCode}, ${response.body}');
        return [];
      }
    } catch (error) {
      print('Error occurred: $error');
      return [];
    }
  }

  static Future<void> followUser(String followedUid, String followedUserName) async {
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
      "FollowingUserName" : followedUserName
    });

    try {
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode != 200) {
        print("Failed to follow user. Status code: ${response.statusCode}");
        print("Response body: ${response.body}");
      }
    } catch (e) {
      print("Error occurred: $e");
    }
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

      if (response.statusCode != 200) {
        print("Failed to unfollow user. Status code: ${response.statusCode}");
        print("Response body: ${response.body}");
      }
    } catch (e) {
      print("Error occurred: $e");
    }
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
        print("Fetching conversations for the following user $userID");

        // Make the POST request
        final response = await http.post(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode(requestBody), // Encode request body to JSON
        );
        print(response.body);
        // Check if the request was successful
        if (response.statusCode == 200) {
          // Parse the response body as JSON
          var responseBody = jsonDecode(response.body);

          // Return the value of the key conversationIds
          return responseBody['conversationIds'];
        }
      } catch (e) {
        // Handle errors and return the error message
        print('Error occurred: $e');
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
          rawCategory = parts.map((part) => part[0].toUpperCase() + part.substring(1)).join(" ");
        }
        
        // Capitalize first letter
        String category = rawCategory.isNotEmpty ? 
                         rawCategory[0].toUpperCase() + rawCategory.substring(1) : 
                         "Entertainment";
        
        return {
          "sentiment": sentiment,
          "category": category,
        };
      }
      return {"sentiment": -1, "category": "Entertainment"};
    } catch (e) {
      print('Error analyzing sentiment: $e');
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
      
      String url = 'https://inzoneapi-912424781531.us-central1.run.app/feed/create-human-post';
      
      Map<String, dynamic> postData = {
        "UserName": FirebaseAuth.instance.currentUser!.displayName,
        "UserDocumentId": FirebaseAuth.instance.currentUser!.uid,
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
        print('Failed to create human post. Status code: ${response.statusCode}');
        print('Response body: ${response.body}');
        return {
          "success": false,
          "sentiment": analysis["sentiment"],
          "error": "Failed to create post",
        };
      }
    } catch (e) {
      print('Error creating human post: $e');
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
      
      String url = 'https://inzoneapi-912424781531.us-central1.run.app/feed/create-ai-post';
      
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
        print('Failed to create AI post. Status code: ${response.statusCode}');
        print('Response body: ${response.body}');
        return {
          "success": false,
          "sentiment": analysis["sentiment"],
          "error": "Failed to create post",
        };
      }
    } catch (e) {
      print('Error creating AI post: $e');
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
      
      String url = 'https://inzoneapi-912424781531.us-central1.run.app/feed/create-repost';
      
      Map<String, dynamic> postData = {
        "UserDocumentId": FirebaseAuth.instance.currentUser!.uid,
        "UserName" : FirebaseAuth.instance.currentUser!.displayName,
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
        print('Failed to create repost. Status code: ${response.statusCode}');
        print('Response body: ${response.body}');
        return {
          "success": false,
          "sentiment": analysis["sentiment"],
          "error": "Failed to create repost",
        };
      }
    } catch (e) {
      print('Error creating repost: $e');
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
        if (responseData.containsKey('success') && responseData['success'] == true && responseData.containsKey('data')) {
          // Extract the sentiment data
          Map<String, dynamic> sentimentData = responseData['data'];
          
          // Validate required keys
          final requiredKeys = ["PositiveScore", "NegativeScore", "NeutralScore", "OverallSentiment", "Categories", "Keywords"];
          if (requiredKeys.every((key) => sentimentData.containsKey(key))) {
            // Get the OverallSentiment value as string
            String overallSentiment = sentimentData['OverallSentiment'].toString();
            print('Raw sentiment value: $overallSentiment'); // Debug print
            
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
                print('Unexpected sentiment value: $overallSentiment');
                sentimentCategory = 0; // Default to neutral for unknown values
            }
            
            return {
              "sentiment": sentimentCategory,
              "category": sentimentData['Categories'].isNotEmpty ? 
                         sentimentData['Categories'][0] : "Entertainment"
            };
          } else {
            print('Missing required keys in sentiment data');
            return null;
          }
        } else if (responseData.containsKey('error')) {
          print('API Error: ${responseData['error']} (Code: ${responseData['code']})');
          return null;
        }
        return null;
      } else {
        print('Failed to analyze sentiment. Status code: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error in sentiment analysis: $e');
      return null;
    }
  }


  static Future<Map<String, dynamic>?> createUserProfile({
    required String name,
    required String email,
    required int age,
    required String userUid,
    required String gender,
    required List<String> userInterests,
    String? bio,
    String? profilePicture,
    String? userName
  }) async {
    String url = "https://inzoneapi-912424781531.us-central1.run.app/user/create-profile";
    
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
      print("Sending request with body: ${json.encode(requestBody)}");
      
      final http.Response response = await http.post(
        Uri.parse(url),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: json.encode(requestBody),
      );
      
      print("Response status code: ${response.statusCode}");
      print("Response body: ${response.body}");
      
      if (response.statusCode == 200) {
        try {
          final Map<String, dynamic> responseData = json.decode(response.body);
          print("Response decoded successfully");
          
          // Check if the response has the expected structure
          if (responseData.containsKey("success") && responseData["success"] == true) {
            return responseData;
          } else {
            print("API returned success: false");
            return null;
          }
        } catch (e) {
          print("Error parsing response: $e");
          return null;
        }
      } else {
        print("Failed to create profile. Status code: ${response.statusCode}");
        print("Response body: ${response.body}");
        return null;
      }
    } catch (e) {
      print('Error creating user profile: $e');
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
        print("Character created successfully");
        print(response.body); // Handle response here
      } else {
        print("Failed to create character: ${response.statusCode}");
      }
    } catch (e) {
      print("Error occurred: $e");
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
        if (jsonResponse.containsKey("success") && jsonResponse["success"] == true) {
          // Check if the data field exists and contains the image URL
          if (jsonResponse.containsKey("data") && 
              jsonResponse["data"] is Map<String, dynamic> &&
              jsonResponse["data"].containsKey("imageUrl")) {
            return jsonResponse["data"]["imageUrl"];
          }
        }
        
        print("Unexpected response format: $jsonResponse");
        return null;
      } else {
        // Handle failure and return null
        print("Failed to generate image: ${response.statusCode}");
        print("Response body: ${response.body}");
        return null;
      }
    } catch (e) {
      print("Error occurred during image generation: $e");
      return null;
    }
  }

  static Future<bool?> logEvent(String eventName, Map? eventValues) async {
    bool? result;
    try {
      result = await appsflyerSdk.logEvent(eventName, eventValues);
    } on Exception {}
    print("Result logEvent: $result");
    return null;
  }


  static Future<bool> updateUserProfile({
    required String userId,
    String? username,
    String? bio,
    String? profilePicture,
  }) async {
    const String url =
        'https://inzoneapi-912424781531.us-central1.run.app/user/update-profile';

    // Build the request body with only the fields that are provided
    Map<String, dynamic> requestBody = {
      "UserId": userId,
    };
    
    // Add optional fields if they are provided
    if (username != null) requestBody["Username"] = username;
    if (bio != null) requestBody["Bio"] = bio;
    if (profilePicture != null) requestBody["ProfilePicture"] = profilePicture;

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
        if (responseData.containsKey("success") && responseData["success"] == true) {
          print("Profile updated successfully");
          return true;
        } else {
          print("API returned success: false");
          return false;
        }
      } else {
        print("Failed to update profile. Status code: ${response.statusCode}");
        print("Response body: ${response.body}");
        return false;
      }
    } catch (e) {
      print('Error updating user profile: $e');
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
        if (responseData.containsKey("success") && responseData["success"] == true) {
          print("Post updated successfully");
          return true;
        } else {
          print("API returned success: false");
          return false;
        }
      } else if (response.statusCode == 404) {
        print("Post not found");
        return false;
      } else {
        print("Failed to update post. Status code: ${response.statusCode}");
        print("Response body: ${response.body}");
        return false;
      }
    } catch (e) {
      print('Error updating post: $e');
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
      print("Cannot write comment: User not logged in");
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
          print("Comment added successfully with ID: ${responseData["commentId"]}");
          return responseData["commentId"];
        } else {
          print("Comment added but no ID returned");
          return null;
        }
      } else {
        print("Failed to add comment. Status code: ${response.statusCode}");
        print("Response body: ${response.body}");
        return null;
      }
    } catch (e) {
      print('Error writing comment: $e');
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
      print("Cannot like post: User not logged in");
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
        if (responseData.containsKey("success") && responseData["success"] == true) {
          print("Post liked successfully");
          return true;
        } else {
          print("API returned success: false");
          return false;
        }
      } else {
        print("Failed to like post. Status code: ${response.statusCode}");
        print("Response body: ${response.body}");
        return false;
      }
    } catch (e) {
      print('Error liking post: $e');
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
      print("Cannot unlike post: User not logged in");
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
        if (responseData.containsKey("success") && responseData["success"] == true) {
          print("Post unliked successfully");
          return true;
        } else {
          print("API returned success: false");
          return false;
        }
      } else {
        print("Failed to unlike post. Status code: ${response.statusCode}");
        print("Response body: ${response.body}");
        return false;
      }
    } catch (e) {
      print('Error unliking post: $e');
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
      print("Cannot remove from following: User not logged in");
      return false;
    }

    // Build the request body
    Map<String, dynamic> requestBody = {
      "FollowerId": currentUserUID, // Current user (who is following)
      "FollowingId": followingId,   // User to unfollow
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
        print("Failed to remove from following. Status code: ${response.statusCode}");
        print("Response body: ${response.body}");
        return false;
      }
    } catch (e) {
      print('Error removing from following: $e');
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
      print("Cannot remove from followers: User not logged in");
      return false;
    }

    // Build the request body
    Map<String, dynamic> requestBody = {
      "FollowerId": currentUserUID, // Current user (who is being followed)
      "FollowingId": followerId,    // User to remove as follower
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
        print("Failed to remove from followers. Status code: ${response.statusCode}");
        print("Response body: ${response.body}");
        return false;
      }
    } catch (e) {
      print('Error removing from followers: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>?> getCarouselCharacters() async {
    const String url =
        'https://inzoneapi-912424781531.us-central1.run.app/api/ai/carousel/characters';

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
        print("Retrieved ${responseData.length} carousel characters");
        
        // Convert the dynamic list to a list of maps
        print(responseData);
        return responseData.map((character) => 
          character as Map<String, dynamic>
        ).toList();
      } else {
        print("Failed to get carousel characters. Status code: ${response.statusCode}");
        print("Response body: ${response.body}");
        return null;
      }
    } catch (e) {
      print('Error getting carousel characters: $e');
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
        print('Retrieved ${rawPosts.length} posts for user $userId');
        
        // Print the raw structure of the first post for debugging
        if (rawPosts.isNotEmpty) {
          print('First raw post structure: ${rawPosts[0]}');
        }
        
        return rawPosts; // Return the raw posts directly without transformation
      } else {
        // Handle unsuccessful requests
        print('Failed to load user posts. Status code: ${response.statusCode}');
        print('Response body: ${response.body}');
        return null;
      }
    } catch (e) {
      // Handle any exceptions
      print('Error occurred while fetching user posts: $e');
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
        print('Retrieved ${rawPosts.length} posts for user $userId');

        // Print the raw structure of the first post for debugging
        if (rawPosts.isNotEmpty) {
          print('First raw post structure: ${rawPosts[0]}');
        }

        return rawPosts; // Return the raw posts directly without transformation
      } else {
        // Handle unsuccessful requests
        print('Failed to load user posts. Status code: ${response.statusCode}');
        print('Response body: ${response.body}');
        return null;
      }
    } catch (e) {
      // Handle any exceptions
      print('Error occurred while fetching user posts: $e');
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
        if (responseData.containsKey("success") && responseData["success"] == true) {
          print("Successfully retrieved AI user profile for $username");
          // Return the user data from the "data" field
          return responseData["data"] as Map<String, dynamic>;
        } else {
          print('API returned success: false - ${responseData["error"] ?? "Unknown error"}');
          return null;
        }
      } else {
        // Handle unsuccessful requests
        print('Failed to load AI user profile. Status code: ${response.statusCode}');
        print('Response body: ${response.body}');
        return null;
      }
    } catch (e) {
      // Handle any exceptions
      print('Error fetching AI user profile: $e');
      return null;
    }
  }

  // Add this method to update user profile
  static Future<void> updateUserProfileData(String userId, Map<String, dynamic> profileData) async {
    try {
      // Convert the profile data to match the API's expected format
      Map<String, dynamic> requestBody = {
        "UserId": userId,
        "Name": profileData['name'],
        "Username": profileData['username'],
        "Bio": profileData['bio'],
      };

      // Remove null values from the request body
      requestBody.removeWhere((key, value) => value == null);

      const String url = 'https://inzoneapi-912424781531.us-central1.run.app/user/update-profile';

      final http.Response response = await http.post(
        Uri.parse(url),
        headers: <String, String>{
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        
        if (responseData.containsKey("success") && responseData["success"] == true) {
          print('User profile updated successfully: $profileData');
        } else {
          throw Exception('API returned success: false - ${responseData["error"] ?? "Unknown error"}');
        }
      } else {
        throw Exception('Failed to update profile. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating user profile: $e');
      rethrow; // Rethrow to handle in UI
    }
  }

  // AI User Follow/Unfollow Functions
  static Future<bool> followAIUser(String aiUserId) async {
    const String url = 'https://inzoneapi-912424781531.us-central1.run.app/user/follow';

    String? currentUserUID = await getCurrentUserUid();
    String? currentUserName = FirebaseAuth.instance.currentUser?.displayName;
    
    if (currentUserUID == null) {
      print("Cannot follow AI user: User not logged in");
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
          'FollowingUserName' : aiUserId
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return responseData['success'] ?? false;
      } else {
        print('Failed to follow AI user. Status code: ${response.statusCode}');
        print('Response body: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error following AI user: $e');
      return false;
    }
  }

  static Future<bool> unfollowAIUser(String aiUserId) async {
    const String url = 'https://inzoneapi-912424781531.us-central1.run.app/user/unfollow';

    String? currentUserUID = await getCurrentUserUid();
    String? currentUserName = FirebaseAuth.instance.currentUser?.displayName;
    
    if (currentUserUID == null) {
      print("Cannot unfollow AI user: User not logged in");
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
          'FollowingUserName':aiUserId
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return responseData['success'] ?? false;
      } else {
        print('Failed to unfollow AI user. Status code: ${response.statusCode}');
        print('Response body: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error unfollowing AI user: $e');
      return false;
    }
  }

  static Future<List<String>> getAIFollowers(String userId) async {
    const String url = 'https://inzoneapi-912424781531.us-central1.run.app/api/ai/get-followers';

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
        print('Failed to get AI followers. Status code: ${response.statusCode}');
        print('Response body: ${response.body}');
        return [];
      }
    } catch (e) {
      print('Error getting AI followers: $e');
      return [];
    }
  }

  static Future<List<String>> getAIFollowing(String userId) async {
    const String url = 'https://inzoneapi-912424781531.us-central1.run.app/api/ai/get-following';

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
        print('Failed to get AI following. Status code: ${response.statusCode}');
        print('Response body: ${response.body}');
        return [];
      }
    } catch (e) {
      print('Error getting AI following: $e');
      return [];
    }
  }

  static Future<bool> removeFromAIFollowers(String followerId) async {
    const String url = 'https://inzoneapi-912424781531.us-central1.run.app/api/ai/remove-from-followers';

    String? currentUserUID = await getCurrentUserUid();
    if (currentUserUID == null) {
      print("Cannot remove AI follower: User not logged in");
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
        print('Failed to remove AI follower. Status code: ${response.statusCode}');
        print('Response body: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error removing AI follower: $e');
      return false;
    }
  }

  static Future<bool> removeFromAIFollowing(String followingId) async {
    const String url = 'https://inzoneapi-912424781531.us-central1.run.app/api/ai/remove-from-following';

    String? currentUserUID = await getCurrentUserUid();
    if (currentUserUID == null) {
      print("Cannot remove from AI following: User not logged in");
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
        print('Failed to remove from AI following. Status code: ${response.statusCode}');
        print('Response body: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error removing from AI following: $e');
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
      print("ERROR: Cannot save post with invalid ID: ${post.id}");
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
    } catch (e) {
      print("Error saving liked post: $e");
    }
  }

  // Remove a post ID from the liked posts
  static Future<void> removeLikedPost(String postId) async {
    // Validate post ID before proceeding
    if (postId == "unknown" || postId.isEmpty) {
      print("ERROR: Cannot remove post with invalid ID: $postId");
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
        } catch (e) {
          print("Error processing post $postId: $e");
        }
      });
      
      return posts;
    } catch (e) {
      print("Error converting liked posts: $e");
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
    
    Map<String, String> likedPosts = Map<String, String>.from(
        jsonDecode(rawData ?? '{}'));
    
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
