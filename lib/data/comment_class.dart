class Comment {
  // ignore: constant_identifier_names
  static const TAG = 'Comment';

  String? avatar;
  String? userName;
  String? content;

  Comment({
    required this.avatar,
    required this.userName,
    required this.content,
  });
}

class ReplyClass {
  String name;
  String text;
  String uid;

  ReplyClass({required this.name, required this.text, required this.uid});

  factory ReplyClass.fromJson(Map<String, dynamic> json) {
    return ReplyClass(name: json['name'], text: json['text'], uid: json['uid']);
  }

  Map<String, dynamic> toJson() {
    return {'name': name, 'text': text, 'uid': uid};
  }
}

class CommentClass extends Comment {
  final String author;
  final String text;
  final String timestamp;
  final String id;
  final String postId;
  final String userId;
  final String? parentCommentId; // For threading - null for root comments
  final int replyCount; // Count of direct replies
  final bool isReply; // Helper to identify if this is a reply
  List<String>? likedBy;
  List<String>? dislikedBy;
  final List<ReplyClass> replies;
  final String? profilePictureUrl;

  CommentClass({
    required this.author,
    required this.text,
    required this.timestamp,
    required this.id,
    required this.postId,
    required this.userId,
    required this.replies,
    this.parentCommentId,
    this.replyCount = 0,
    this.isReply = false,
    this.likedBy,
    this.dislikedBy,
    this.profilePictureUrl,
  }) : super(avatar: "avatar", userName: author, content: text);
  //
  // factory CommentClass.fromJson(Map<String, dynamic> json) {
  //   return CommentClass(
  //     author: json['author'],
  //     text: json['text'],
  //     timestamp: json['timestamp'],
  //     id: json['uid'] ?? '',
  //     postId: json['postId'],
  //     userId: json['userId'],
  //     replies: json['replies'] != null
  //         ? List<ReplyClass>.from(
  //         json['replies'].map((reply) => ReplyClass.fromJson(reply)))
  //         : [],
  //     likedBy:
  //         json['likedBy'] != null ? List<String>.from(json['likedBy']) : [],
  //     dislikedBy: json['dislikedBy'] != null
  //         ? List<String>.from(json['dislikedBy'])
  //         : [],
  //   );
  // }
  //
  // Map<String, dynamic> toJson() {
  //   return {
  //     'author': author,
  //     'text': text,
  //     'timestamp': timestamp,
  //     'id': id,
  //     'postId': postId,
  //     'userId': userId,
  //     'replies': replies.map((reply) => reply.toJson()).toList(),
  //     'likedBy': likedBy,
  //     'dislikedBy': dislikedBy,
  //   };
  // }

  factory CommentClass.fromJson(Map<String, dynamic> json) {
    return CommentClass(
      author: json['name'] ?? json['author'] ?? '',
      text: json['text'] ?? '',
      timestamp: json['timestamp'].toString(),
      id: json['uid'] ?? json['id'] ?? '',
      postId: json['postId'] ?? '',
      userId: json['userId'] ?? '',
      parentCommentId: json['parentCommentId'],
      replyCount: json['replyCount'] ?? 0,
      isReply: json['parentCommentId'] != null,
      replies: json['replies'] != null
          ? List<ReplyClass>.from(
              json['replies'].map((reply) => ReplyClass.fromJson(reply)))
          : [],
      likedBy:
          json['likedBy'] != null ? List<String>.from(json['likedBy']) : [],
      dislikedBy: json['dislikedBy'] != null
          ? List<String>.from(json['dislikedBy'])
          : [],
      profilePictureUrl: json['profilePicture'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': author,
      'author': author,
      'text': text,
      'timestamp': timestamp,
      'uid': id,
      'id': id,
      'postId': postId,
      'userId': userId,
      'parentCommentId': parentCommentId,
      'replyCount': replyCount,
      'replies': replies.map((reply) => reply.toJson()).toList(),
      'likedBy': likedBy,
      'dislikedBy': dislikedBy,
      'profilePicture': profilePictureUrl,
    };
  }
}
