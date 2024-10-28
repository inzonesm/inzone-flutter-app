
import 'package:inzone/data/comment_class.dart';
class InZonePost

{
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
  });

  // Convert InZonePost object to a JSON-compatible map
  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'userName': userName,
      'likes': likes,
      'id': id,
      'imageContent': imageContent,
      'videoContent': videoContent,
      'textContent': textContent,
      'userReference': userReference,
      'mainCategory': mainCategory,
    };
  }
// Create InZonePost object from JSON
  factory InZonePost.fromJsonLocal(Map<String, dynamic> json) {
    return InZonePost(
      category: json['category'],
      userName: json['userName'],
      likes: json['likes'],
      id: json['id'],
      imageContent: List<String>.from(json['imageContent']),  // Convert JSON array to List<String>
      videoContent: List<String>.from(json['videoContent']),  // Convert JSON array to List<String>
      textContent: json['textContent'],
      userReference: json['userReference'],
      mainCategory: json['mainCategory'], comments: [], datePosted: DateTime.now(),
    );
  }
  static InZonePost fromJson(Map<String, dynamic> json) {
    // Extract the 'data' field from the JSON or assign an empty map if it's missing
    Map<String, dynamic> data = json['data'] ?? {};

    // Safely initialize variables with default values
    String category = data['category'] ?? 'animals';
    String userName = data['user_name'] ?? 'Unknown';
    int likes = data['likes'] ?? 0;
    String id = json['id'] ?? 'unknown';
    String textContent = (data['post'] != null && data['post']['textContent'] != null)
        ? data['post']['textContent']
        : '';
    String userReference = data['user_references'] ?? 'unknown';
    String mainCategory = data['sub_category'] ?? '';
    DateTime datePosted = DateTime.now(); // Assuming current time if not provided

    // Initialize imageList
    List<String> imageList = [];
    List<String> videoList = [];

    // Handle image content safely
    if (data['post'] != null && data['post']['image_content'] != null) {
      if (data['post']['image_content'] is List) {
        List<dynamic> imageContentList = List.from(data['post']['image_content']);
        for (var element in imageContentList) {
          imageList.add(element.toString());
        }
      } else if (data['post']['image_content'] is String) {
        imageList.add(data['post']['image_content']);
      }
    }
    if (data['post'] != null && data['post']['video_content'] != null) {
      if (data['post']['video_content'] is List) {
        List<dynamic> videoContentList = List.from(data['post']['video_content']);
        for (var element in videoContentList) {
          videoList.add(element.toString());
        }
      } else if (data['post']['video_content'] is String) {
        videoList.add(data['post']['video_content']);
      }
    }

    // Safely handle comments
    List<dynamic> commentsList = [];
    if (data['comments'] is Map && (data['comments'] as Map).isEmpty) {
      commentsList = [];
    } else if (data['comments'] is List) {
      commentsList = data['comments'] as List<dynamic>;
    } else if (data['comments'] != null) {
      commentsList = [data['comments']];
    }

    // Prepare final comments list
    List<CommentClass> finalCommentsList = commentsList.map((elem) {
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
        timestamp: DateTime.now().toString(), // Placeholder, replace with actual timestamp
        id: elem['uid'] ?? '',
        postId: json['id'] ?? 'Error', // Fallback to 'Error' if postId is missing
        userId: data['user_name'] ?? 'Unknown',
        replies: repliesList,
        likedBy: elem['likedBy'] != null ? List<String>.from(elem['likedBy']) : [],
        dislikedBy: elem['dislikedBy'] != null ? List<String>.from(elem['dislikedBy']) : [],
      );
    }).toList();

    // Safely return the constructed InZonePost object
    return InZonePost(
      category: category,
      userName: userName,
      comments: finalCommentsList,
      datePosted: datePosted,
      likes: likes,
      id: id,
      imageContent: imageList,
      videoContent: [], // Add logic if needed for videoContent
      textContent: textContent,
      userReference: userReference,
      mainCategory: mainCategory,
    );
  }
  static InZonePost fromJsonForHumans(Map<String, dynamic> json) {
    // Extract the 'data' field from the JSON or assign an empty map if it's missing
    Map<String, dynamic> data = json;

    // Safely initialize variables with default values
    String category = data['category'] ?? 'animals';
    String userName = data['user_name'] ?? 'Unknown';
    int likes = data['likes'] ?? 0;
    String id = json['id'] ?? 'unknown';
    String textContent = (data['post'] != null && data['post']['textContent'] != null)
        ? data['post']['textContent']
        : '';
    String userReference = data['user_references'] ?? 'unknown';
    String mainCategory = data['sub_category'] ?? '';
    DateTime datePosted = DateTime.now(); // Assuming current time if not provided

    // Initialize imageList
    List<String> imageList = [];
    List<String> videoList = [];

    // Handle image content safely
    if (data['post'] != null && data['post']['image_content'] != null) {
      if (data['post']['image_content'] is List) {
        List<dynamic> imageContentList = List.from(data['post']['image_content']);
        for (var element in imageContentList) {
          imageList.add(element.toString());
        }
      } else if (data['post']['image_content'] is String) {
        imageList.add(data['post']['image_content']);
      }
    }
    if (data['post'] != null && data['post']['video_content'] != null) {
      if (data['post']['video_content'] is List) {
        List<dynamic> videoContentList = List.from(data['post']['video_content']);
        for (var element in videoContentList) {
          videoList.add(element.toString());
        }
      } else if (data['post']['video_content'] is String) {
        videoList.add(data['post']['video_content']);
      }
    }

    // Safely handle comments
    List<dynamic> commentsList = [];
    if (data['comments'] is Map && (data['comments'] as Map).isEmpty) {
      commentsList = [];
    } else if (data['comments'] is List) {
      commentsList = data['comments'] as List<dynamic>;
    } else if (data['comments'] != null) {
      commentsList = [data['comments']];
    }

    // Prepare final comments list
    List<CommentClass> finalCommentsList = commentsList.map((elem) {
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
        timestamp: DateTime.now().toString(), // Placeholder, replace with actual timestamp
        id: elem['uid'] ?? '',
        postId: json['id'] ?? 'Error', // Fallback to 'Error' if postId is missing
        userId: data['user_name'] ?? 'Unknown',
        replies: repliesList,
        likedBy: elem['likedBy'] != null ? List<String>.from(elem['likedBy']) : [],
        dislikedBy: elem['dislikedBy'] != null ? List<String>.from(elem['dislikedBy']) : [],
      );
    }).toList();

    // Safely return the constructed InZonePost object
    return InZonePost(
      category: category,
      userName: userName,
      comments: finalCommentsList,
      datePosted: datePosted,
      likes: likes,
      id: id,
      imageContent: imageList,
      videoContent: [], // Add logic if needed for videoContent
      textContent: textContent,
      userReference: userReference,
      mainCategory: mainCategory,
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
