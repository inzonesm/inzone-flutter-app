import 'dart:convert';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:inzone/data/inzone_post.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'main.dart';

class InZoneDatabase {
  static Future<Map<String, dynamic>?> getFeed() async {
    String url =
        'https://us-central1-inzonebackend.cloudfunctions.net/api/get_posts';

    try {
      // Make the POST request
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      // Check if the response status code is 200 (OK)
      if (response.statusCode == 200) {
        // Decode the response body
        final Map<String, dynamic> jsonMap = jsonDecode(response.body);

        // Ensure the expected data structure is valid
        if (jsonMap != null && jsonMap is Map<String, dynamic>) {
          // Return the decoded JSON map
          return jsonMap;
        } else {
          // Return null if the response body is not a valid JSON map
          return null;
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

  static Future<Map<String, dynamic>?> getHumanFeed() async {
    String url =
        'https://us-central1-inzonebackend.cloudfunctions.net/api/feed/getHumanPosts';

    try {
      // Make the POST request
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );
print(response.body);
      // Check if the response status code is 200 (OK)
      if (response.statusCode == 200) {
        // Decode the response body
        final Map<String, dynamic> jsonMap = jsonDecode(response.body);

        // Ensure the expected data structure is valid
        if (jsonMap != null && jsonMap is Map<String, dynamic>) {
          // Return the decoded JSON map
          return jsonMap;
        } else {
          // Return null if the response body is not a valid JSON map
          return null;
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
    String url =
        'https://us-central1-inzonebackend.cloudfunctions.net/api/ai/chat';
    String? currentUserUID;
    Map<String, String> requestBody = {};
    await InZoneDatabase.getCurrentUserUid().then((value) {
      if (value != null) {
        currentUserUID = value;
      }
    });
    if (currentUserUID != null) {
      try {
        // Create the request body
        if (chatID != null) {
          requestBody = {
            'userMessage': userMessage,
            'aiUid': aiUsername,
            'userUid': currentUserUID!,
            'chatID': chatID
          };
        } else {
          requestBody = {
            'userMessage': userMessage,
            'aiUid': aiUsername,
            'userUid': currentUserUID!,
          };
        }
        print("Sending message with the following request body");
        print(requestBody);
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
  }

  static Future<String?> startConversation(String aiUsername) async {
    String url =
        'https://us-central1-inzonebackend.cloudfunctions.net/api/ai/chat';
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
  }

  static Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    // API endpoint URL
    final String url =
        'https://us-central1-inzonebackend.cloudfunctions.net/api/user/get-profile';
    String? currentUserUID;
    await InZoneDatabase.getCurrentUserUid().then((value) {
      print(value);
      if (value != null) {
        currentUserUID = value;
      }
    });
    // Create the request body
    final Map<String, dynamic> requestBody = {
      'userUid': '4zQrT4Zd1oMFjlaPDEz3wWcJSOv2',
    };
    try {
      final http.Response response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody), // Convert Map to JSON string
      );

      // Check if the request was successful (status code 200-299)
      if (response.statusCode == 200) {
        // Parse the response body and return as Map
        print(response.body);
        return jsonDecode(response.body) as Map<String, dynamic>;
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
    // API endpoint URL
    final String url =
        'https://us-central1-inzonebackend.cloudfunctions.net/api/user/get-profile';

    // Create the request body
    final Map<String, dynamic> requestBody = {
      'userUid': userID,
    };
    try {
      final http.Response response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody), // Convert Map to JSON string
      );

      // Check if the request was successful (status code 200-299)
      if (response.statusCode == 200) {
        // Parse the response body and return as Map
        print(response.body);
        return jsonDecode(response.body) as Map<String, dynamic>;
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

  static Future<void> getFollowers(String userUid) async {
    final url = Uri.parse(
        'https://us-central1-inzonebackend.cloudfunctions.net/api/user/get-followers');

    try {
      final response = await http.post(
        url,
        headers: <String, String>{
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, String>{
          'userUid': userUid,
        }),
      );

      if (response.statusCode == 200) {
        // Successful request
        final responseData = jsonDecode(response.body);
        print('Followers: $responseData');
        // Process the response data as needed
      } else {
        // Handle errors
        print('Error: ${response.statusCode}, ${response.body}');
      }
    } catch (error) {
      print('Error occurred: $error');
    }
  }

  static Future<void> followUser(String followedUid) async {
    final url = Uri.parse(
        'https://us-central1-inzonebackend.cloudfunctions.net/api/user/follow');
    final headers = {"Content-Type": "application/json"};
    String? currentUserUID;
    await InZoneDatabase.getCurrentUserUid().then((value) {
      if (value != null) {
        currentUserUID = value;
      }
    });
    final body = jsonEncode({
      "userUid": currentUserUID,
      "followedUid": followedUid,
    });

    try {
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        print("Successfully followed user.");
      } else {
        print("Failed to follow user. Status code: ${response.statusCode}");
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
  }

  static Future<int> postContent({
    required String postMessage,
    required List<String> imageRef,
    required List<String> videoRef,
    String? aiName,
    String? aiProfileImageURL,
    String? aiChatContent,
    String? avatarID

  }) async {
    String category = "Unknown"; // Default category
    int sentiment = -10;

    try {
      var value = await InZoneDatabase.sendSentimentRequest(postMessage);
      print(value);
      if (value != null && int.parse(value["sentiment"]) != -1) {
        sentiment = int.parse(value["sentiment"]);
        try {
          category = value["category"];
          if (category.contains("-")) {
            List<String> parts = category.split('-');
            parts.map((part) => part[0].toUpperCase() + part.substring(1));
            parts.join(" ");
          }
          DateTime now = DateTime.now();
          int currentHour = now.hour;
          if (category.length < 1) {
            category = "Entertainment";
          }
          String url =
              'https://us-central1-inzonebackend.cloudfunctions.net/api/feed/create-post';
           Map<String, dynamic> postData = {};
          // Construct the post data
          if (aiName != null){
            postData = {
              "post" : {
                "category": category,
                "sub_category": category,
                "user_name": FirebaseAuth.instance.currentUser!.displayName,
                "likes": 0,
                "post": {"textContent": postMessage, "image_content": imageRef, "video_content" : videoRef},
                "user_references": FirebaseAuth.instance.currentUser!.email,
                "comments": [],
                "uid": FirebaseAuth.instance.currentUser!.uid,
                "aiName": aiName,
                "aiProfileImageURL" : aiProfileImageURL!,
                "aiChatContent" : aiChatContent!,
                "avatarID" : avatarID!
              },
            };
          } else {
            postData = {
              "post": {
                "category": category,
                "sub_category": category,
                "user_name": FirebaseAuth.instance.currentUser!.displayName,
                "likes": 0,
                "post": {"textContent": postMessage, "image_content": imageRef, "video_content" : videoRef},
                "user_references": FirebaseAuth.instance.currentUser!.email,
                "comments": [],
                "uid": FirebaseAuth.instance.currentUser!.uid
              },
            };
          }


          try {
            // Make the POST request
            final response = await http.post(
              Uri.parse(url),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body:
                  jsonEncode(postData), // Encode the postData as a JSON string
            );

            // Check if the response status code is 200 (OK) or success code like 201 (Created)
            if (response.statusCode == 200 || response.statusCode == 201) {
              print("Post successful");
              // // If the post was created successfully, return true
              // return true;
            } else {
              // Log the failure with the status code
              print(
                  'Failed to create post. Status code: ${response.statusCode}');
              // return false;
            }
          } catch (e) {
            // Handle any other exceptions
            print('Error occurred: $e');
            // return false;
          }
        } catch (e) {
          category = "Entertainment"; // Default to entertainment on error
        }
      }
    } catch (e) {}

    return sentiment;
  }

  static Future<Map<String, dynamic>?> sendSentimentRequest(String body) async {
    const String url =
        'https://us-central1-inzonebackend.cloudfunctions.net/api/sentiment-analysis';
    try {
      final http.Response response = await http.post(
        Uri.parse(url),
        headers: <String, String>{
          'Content-Type': 'text/plain; charset=UTF-8',
        },
        body: body, // Send raw text directly as the body
      );

      if (response.statusCode == 200) {
        // Assuming the response is JSON, decode it
        final Map<String, dynamic> responseData = json.decode(response.body);

        return responseData;
      } else {
        return null;
      }
    } catch (e) {
      // Handle any errors that occur during the request

      return null;
    }
  }

  static Future<Map<String, dynamic>?> createUserProfile(
      {required String name,
      required String email,
      required int age,
      required String userUid,
      required String gender,
      required List<String> userInterests}) async {
    String url =
        "https://us-central1-inzonebackend.cloudfunctions.net/api/user/create-profile";
    // Construct the JSON body
    final Map<String, dynamic> requestBody = {
      "username": name,
      "email": email,
      "age": age,
      "gender": gender,
      "user_interests": userInterests,
      "userUid": userUid,
    };

    try {
      print("Request body");
      print(requestBody);
      final http.Response response = await http.post(
        Uri.parse(url),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: json.encode(requestBody), // Encode the request body as JSON
      );
      print(response.statusCode);
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        print("Response recevied");
        print(responseData);
        return responseData;
      } else {
        return null;
      }
    } catch (e) {
      // Handle any exceptions that might occur (e.g., network errors)
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
        'https://us-central1-inzonebackend.cloudfunctions.net/api/ai/generate-image';

    Map<String, String> headers = {"Content-Type": "application/json"};
    Map<String, dynamic> body = {"imagePrompt": imagePrompt};

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        // Decode the JSON response body and return the "image_url"
        Map<String, dynamic> jsonResponse = jsonDecode(response.body);
        return jsonResponse["image_url"];
      } else {
        // Handle failure and return null or an error message
        print("Failed to generate image: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("Error occurred: $e");
      return null; // Handle error by returning null or an appropriate error message
    }
  }

  static Future<bool?> logEvent(String eventName, Map? eventValues) async {
    bool? result;
    try {
      result = await appsflyerSdk.logEvent(eventName, eventValues);
    } on Exception catch (e) {}
    print("Result logEvent: $result");
  }
}

class LikedPostsPreferences {
  static const String likedPostsKey = 'likedPostDetails';

  // Add a post (InZonePost) to the liked posts
  static Future<void> addLikedPost(InZonePost post) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Retrieve the current liked posts as a map of postId -> post details (as JSON strings)
    Map<String, String> likedPosts = Map<String, String>.from(
        jsonDecode(prefs.getString(likedPostsKey) ?? '{}'));

    // Serialize the InZonePost object into a JSON string
    String postJson = jsonEncode(post.toJson());

    // Add or update the post details in the map using the post ID as the key
    likedPosts[post.id] = postJson;

    // Save the updated liked posts back to SharedPreferences
    await prefs.setString(likedPostsKey, jsonEncode(likedPosts));
  }

  // Remove a post ID from the liked posts
  static Future<void> removeLikedPost(String postId) async {
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
    Map<String, String> likedPosts = Map<String, String>.from(
        jsonDecode(prefs.getString(likedPostsKey) ?? '{}'));

    // Convert the map back into a list of InZonePost objects
    List<InZonePost> posts = likedPosts.values.map((postJson) {
      Map<String, dynamic> postMap = jsonDecode(postJson);
      return InZonePost.fromJsonLocal(postMap);
    }).toList();

    return posts;
  }

  // Check if a specific post is liked by its ID
  static Future<bool> isPostLiked(String postId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Retrieve the liked posts
    Map<String, String> likedPosts = Map<String, String>.from(
        jsonDecode(prefs.getString(likedPostsKey) ?? '{}'));

    return likedPosts.containsKey(postId);
  }
}
