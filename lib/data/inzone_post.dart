import 'package:inzone/data/comment_class.dart';
import 'package:flutter/foundation.dart'; // Added for debugPrint

class InZonePost {
  final String category;
  final String userName;
  final List<CommentClass> comments;
  final DateTime datePosted;
  final int likes;
  final String id;
  final List<String> imageContent;
  final List<String> videoContent;
  final String textContent;
  final String userReference;
  final String mainCategory;
  final bool isAi;
  final Map<String, dynamic>? characterInfo;

  InZonePost({
    required this.category,
    required this.userName,
    required this.comments,
    required this.datePosted,
    required this.likes,
    required this.id,
    required this.imageContent,
    required this.videoContent,
    required this.textContent,
    required this.userReference,
    required this.mainCategory,
    required this.isAi,
    this.characterInfo,
  });

  // Convert InZonePost object to a JSON-compatible map
  Map<String, dynamic> toJson() {
    // Create a map with all necessary fields
    Map<String, dynamic> jsonMap = {
      'category': category,
      'userName': userName,
      'likes': likes,
      'id': id,
      'imageContent': imageContent,
      'videoContent': videoContent,
      'textContent': textContent,
      'userReference': userReference,
      'mainCategory': mainCategory,
      'isAi': isAi,
      if (characterInfo != null) 'character_info': characterInfo,
      // We don't include comments as they're complex objects
      // We don't include datePosted as it's a DateTime object
    };

    return jsonMap;
  }

// Create InZonePost object from JSON
  factory InZonePost.fromJsonLocal(Map<String, dynamic> json) {
    try {
      // Handle image and video content safely
      List<String> imageContent = [];
      if (json['imageContent'] != null) {
        imageContent = List<String>.from(json['imageContent']);
      }

      List<String> videoContent = [];
      if (json['videoContent'] != null) {
        videoContent = List<String>.from(json['videoContent']);
      }

      // Create the InZonePost object with all fields
      InZonePost post = InZonePost(
        category: json['category'] ?? '',
        userName: json['userName'] ?? 'Unknown',
        likes: json['likes'] ?? 0,
        id: json['id'] ?? 'unknown',
        imageContent: imageContent,
        videoContent: videoContent,
        textContent: json['textContent'] ?? '',
        userReference: json['userReference'] ?? '',
        mainCategory: json['mainCategory'] ?? '',
        isAi: json['isAi'] ?? false,
        comments: [], // Initialize with empty comments
        datePosted:
            DateTime.now().toUtc(), // Use current time as default in UTC
      );

      return post;
    } catch (e) {
      // Return a default post in case of error
      return InZonePost(
        category: '',
        userName: 'Error',
        likes: 0,
        id: 'error',
        imageContent: [],
        videoContent: [],
        textContent: 'Error loading post: $e',
        userReference: '',
        mainCategory: '',
        isAi: false,
        comments: [],
        datePosted: DateTime.now().toUtc(),
      );
    }
  }
  static InZonePost fromJson(Map<String, dynamic> json) {
    // Use the json directly instead of looking for a data field

    // Safely initialize variables with default values
    String category;
    try {
      // Check if category is a list and not empty
      if (json['category'] is List && (json['category'] as List).isNotEmpty) {
        category = json['category'][0] ?? 'General';
      } else {
        // Default category if the list is empty or not a list
        category = 'General';
      }
    } catch (e) {
      category = 'General';
    }

    String userName = json['user_name'] ?? 'Unknown';
    int likes = json['likes'] ?? 0;

    // More robust ID handling
    String id;
    if (json.containsKey('id') &&
        json['id'] != null &&
        json['id'].toString().isNotEmpty) {
      id = json['id'].toString();
    } else if (json.containsKey('_id') &&
        json['_id'] != null &&
        json['_id'].toString().isNotEmpty) {
      id = json['_id'].toString();
    } else {
      // Generate a unique ID based on content and timestamp if no ID is available
      String timestamp =
          DateTime.now().toUtc().millisecondsSinceEpoch.toString();
      String contentHash = userName;
      id = "generated_${contentHash.hashCode}_$timestamp";
    }

    // Handle text content
    String textContent = '';
    try {
      if (json['post'] != null) {
        if (json['post'] is Map) {
          if (json['post']['text_content'] != null) {
            textContent = json['post']['text_content'].toString();
          }
        }
      }
    } catch (e) {}

    String userReference = json['user_name'] ?? 'unknown';

    // Parse date_posted if available
    DateTime datePosted;
    try {
      if (json['date_posted'] != null) {
        datePosted = DateTime.parse(json['date_posted']).toUtc();
      } else {
        datePosted = DateTime.now().toUtc();
      }
    } catch (e) {
      datePosted = DateTime.now().toUtc();
    }

    // Initialize imageList and videoList
    List<String> imageList = [];
    List<String> videoList = [];

    // Handle image content safely
    try {
      if (json['post'] != null) {
        // Get image content
        var imageContent = json['post']['image_content'];

        if (imageContent != null) {
          if (imageContent is List) {
            for (var element in imageContent) {
              if (element != null) {
                imageList.add(element.toString());
              }
            }
          } else if (imageContent is String) {
            imageList.add(imageContent);
          }
        }

        // Get video content
        var videoContent = json['post']['video_content'];

        if (videoContent != null) {
          if (videoContent is List) {
            for (var element in videoContent) {
              if (element != null) {
                videoList.add(element.toString());
              }
            }
          } else if (videoContent is String) {
            videoList.add(videoContent);
          }
        }
      }
    } catch (e) {}

    // Safely handle comments
    List<dynamic> commentsList = [];
    debugPrint('Fetched video URLs: $videoList');
    if (json['comments'] is Map && (json['comments'] as Map).isEmpty) {
      commentsList = [];
    } else if (json['comments'] is List) {
      commentsList = json['comments'] as List<dynamic>;
    } else if (json['comments'] != null) {
      commentsList = [json['comments']];
    }

    // Prepare final comments list
    List<CommentClass> finalCommentsList = [];
    try {
      finalCommentsList = commentsList.map((elem) {
        List<ReplyClass> repliesList = [];

        if (elem['replies'] != null) {
          List<dynamic> replies = elem['replies'] as List<dynamic>;
          for (var reply in replies) {
            repliesList.add(ReplyClass(
              name: reply['name'] ?? 'Unknown',
              text: reply['text'] ?? '',
              uid: reply['uid'] ?? '',
            ));
          }
        }

        return CommentClass(
          author: elem['name'] ?? 'Unknown',
          text: elem['text'] ?? '',
          timestamp: DateTime.now().toUtc().millisecondsSinceEpoch.toString(),
          id: elem['uid'] ?? '',
          postId:
              json['id'] ?? 'Error', // Fallback to 'Error' if postId is missing
          userId: json['user_name'] ?? 'Unknown',
          replies: repliesList,
          likedBy:
              elem['likedBy'] != null ? List<String>.from(elem['likedBy']) : [],
          dislikedBy: elem['dislikedBy'] != null
              ? List<String>.from(elem['dislikedBy'])
              : [],
        );
      }).toList();
    } catch (e) {}

    final characterInfo = json['character_info'] as Map<String, dynamic>?;

    // Safely return the constructed InZonePost object
    return InZonePost(
      category: category,
      userName: userName,
      comments: finalCommentsList,
      datePosted: datePosted,
      likes: likes,
      id: id,
      imageContent: imageList,
      videoContent: videoList,
      textContent: textContent,
      userReference: userReference,
      mainCategory: category,
      isAi: json.containsKey('is_ai') ? json['is_ai'] == true : false,
      characterInfo: characterInfo,
    );
  }

  static InZonePost fromJsonForHumans(Map<String, dynamic> json) {
    Map<String, dynamic> data = json;

    // Safely initialize variables with default values
    String category;
    try {
      // Check if category is a list and not empty
      if (data['category'] is List && (data['category'] as List).isNotEmpty) {
        category = data['category'][0] ?? 'animals';
      } else {
        // Default category if the list is empty or not a list
        category = 'animals';
      }
    } catch (e) {
      // Fallback in case of any error
      category = 'animals';
    }

    String userName = data['user_name'] ?? 'Unknown';
    int likes = data['likes'] ?? 0;

    // More robust ID handling
    String id;
    if (json.containsKey('id') &&
        json['id'] != null &&
        json['id'].toString().isNotEmpty) {
      id = json['id'].toString();
    } else if (json.containsKey('_id') &&
        json['_id'] != null &&
        json['_id'].toString().isNotEmpty) {
      id = json['_id'].toString();
    } else {
      // Generate a unique ID based on content and timestamp if no ID is available
      String timestamp =
          DateTime.now().toUtc().millisecondsSinceEpoch.toString();
      String contentHash = userName;
      id = "generated_${contentHash.hashCode}_$timestamp";
    }

    // Handle text content
    String textContent = '';
    try {
      if (data['post'] != null) {
        if (data['post'] is Map) {
          if (data['post']['text_content'] != null) {
            textContent = data['post']['text_content'].toString();
          }
        }
      }
    } catch (e) {}

    String userReference = json['user_document_id'] ?? 'unknown';
    String mainCategory =
        json['category'] is List && (json['category'] as List).isNotEmpty
            ? json['category'][0]
            : '';
    DateTime datePosted =
        DateTime.now().toUtc(); // Assuming current time if not provided

    // Initialize imageList and videoList
    List<String> imageList = [];
    List<String> videoList = [];

    // Handle image content safely
    try {
      if (data['post'] != null) {
        // Get image content
        var imageContent = data['post']['image_content'];

        if (imageContent != null) {
          if (imageContent is List) {
            for (var element in imageContent) {
              if (element != null) {
                imageList.add(element.toString());
              }
            }
          } else if (imageContent is String) {
            imageList.add(imageContent);
          }
        }

        // Get video content
        var videoContent = data['post']['video_content'];

        if (videoContent != null) {
          if (videoContent is List) {
            for (var element in videoContent) {
              if (element != null) {
                videoList.add(element.toString());
              }
            }
          } else if (videoContent is String) {
            videoList.add(videoContent);
          }
        }
      }
    } catch (e) {}

    debugPrint('Fetched video URLs (for humans): $videoList');

    // Safely handle comments
    List<CommentClass> finalCommentsList = [];
    try {
      if (json['comments'] != null && json['comments'] is List) {
        List<dynamic> commentsList = json['comments'] as List<dynamic>;
        finalCommentsList = commentsList.map((elem) {
          List<ReplyClass> repliesList = [];

          if (elem['replies'] != null) {
            List<dynamic> replies = elem['replies'] as List<dynamic>;
            for (var reply in replies) {
              repliesList.add(ReplyClass(
                name: reply['name'] ?? 'Unknown',
                text: reply['text'] ?? '',
                uid: reply['uid'] ?? '',
              ));
            }
          }

          return CommentClass(
            author: elem['name'] ?? 'Unknown',
            text: elem['text'] ?? '',
            timestamp: DateTime.now().toUtc().millisecondsSinceEpoch.toString(),
            id: elem['uid'] ?? '',
            postId: json['id'] ?? 'Error',
            userId: json['user_name'] ?? 'Unknown',
            replies: repliesList,
            likedBy: elem['likedBy'] != null
                ? List<String>.from(elem['likedBy'])
                : [],
            dislikedBy: elem['dislikedBy'] != null
                ? List<String>.from(elem['dislikedBy'])
                : [],
          );
        }).toList();
      }
    } catch (e) {}

    final characterInfo = data['character_info'] as Map<String, dynamic>?;

    // Safely return the constructed InZonePost object
    return InZonePost(
      category: category,
      userName: userName,
      comments: finalCommentsList,
      datePosted: datePosted,
      likes: likes,
      id: id,
      imageContent: imageList,
      videoContent: videoList,
      textContent: textContent,
      userReference: userReference,
      isAi: json.containsKey('is_ai') ? json['is_ai'] == true : false,
      mainCategory: mainCategory,
      characterInfo: characterInfo,
    );
  }

// Factory method to parse a single post
//   static InZonePost fromJson(Map<String, dynamic> json) {
//     Map<String, dynamic> data = json['data'] ?? {};
//     List<String> imageList = [];
//
//     // Safely handle the comments field: If it's an empty object, treat it as an empty list
//     List<dynamic> commentsList = [];
//
//     if (data['comments'] is Map && (data['comments'] as Map).isEmpty) {
//       commentsList = [];
//     } else if (data['comments'] is List) {
//       commentsList = data['comments'] as List<dynamic>;
//     } else if (data['comments'] != null) {
//       commentsList = [data['comments']];
//     }
//
//     // Prepare the list of comments to be added to the post
//     List<CommentClass> finalCommentsList = commentsList.map((elem) {
//       List<ReplyClass> repliesList = [];
//
//       if (elem['replies'] != null) {
//         List<dynamic> replies = elem['replies'] as List<dynamic>;
//         replies.forEach((reply) {
//           repliesList.add(ReplyClass(
//             name: reply['name'] ?? 'Unknown',
//             text: reply['text'] ?? '',
//             uid: reply['uid'] ?? '',
//           ));
//         });
//       }
//
//       return CommentClass(
//         author: elem['name'] ?? "Unknown",
//         text: elem['text'] ?? "",
//         timestamp: DateTime.now().toString(), // Replace with actual timestamp if available
//         id: elem['uid'] ?? '',
//         postId: json['id'] ?? "Error", // Use a default value if postId is missing
//         userId: data['user_name'] ?? 'Unknown',
//         replies: repliesList,
//         likedBy: elem['likedBy'] != null ? List<String>.from(elem['likedBy']) : [],
//         dislikedBy: elem['dislikedBy'] != null ? List<String>.from(elem['dislikedBy']) : [],
//       );
//     }).toList();
// // Check if 'image_content' exists first
//     if (data['post'] != null && data['post']['image_content'] != null) {
//       // Use the 'is' operator to check the type of 'image_content'
//       if (data['post']['image_content'] is List) {
//         // Convert it to a Dart list
//         List<dynamic> imageContentList = List.from(data['post']['image_content']);
//
//         // Print all elements in the list
//         print('image_content is a List with ${imageContentList.length} elements:');
//         for (var element in imageContentList) {
//           print(element);
//           imageList.add(element);
//         }
//       } else if (data['post']['image_content'] is String) {
//         print('image_content is a String: ${data['post']['image_content']}');
//       } else if (data['post']['image_content'] is Map) {
//         print('image_content is a Map: ${data['post']['image_content']}');
//       } else {
//         print('image_content is of an unknown type: ${data['post']['image_content'].runtimeType}');
//       }
//     } else {
//       print('image_content is null or data[\'post\'] is null');
//     }
//
//     return InZonePost(
//       category: data['category'] ?? 'animals',
//       userName: data['user_name'] ?? 'Unknown',
//       comments: finalCommentsList,
//       datePosted: DateTime.now(),
//       likes: data['likes'] ?? 0,
//       id: json['id'] ?? 'unknown',
//       imageContent: imageList,
//       videoContent: [],
//       textContent: data['post']['textContent'] ?? '',
//       userReference: data['user_references'] ?? 'unknown',
//       mainCategory: data['sub_category'] ?? '',
//     );
//   }
}
