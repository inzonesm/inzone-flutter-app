import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:inzone/screen/chat/all_chats_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:inzone/services/account_lifecycle_service.dart';
import 'package:inzone/services/notification_event_service.dart';

class UploadCancelledException implements Exception {
  final String message;

  UploadCancelledException([this.message = 'Upload cancelled by user']);

  @override
  String toString() => message;
}

class AuthWork {
  static FirebaseAuth auth = FirebaseAuth.instance;
  static FirebaseFirestore firestore = FirebaseFirestore.instance;
  static FirebaseStorage storage = FirebaseStorage.instance;

  static User get user => auth.currentUser!;

  static Future<void> _autoReactivateIfDeactivated(User? currentUser) async {
    if (currentUser == null) {
      return;
    }

    try {
      final userDoc =
          await firestore.collection('humanUsers').doc(currentUser.uid).get();
      if (!userDoc.exists) {
        return;
      }

      final data = userDoc.data() ?? {};
      final hasPendingDeletion = data['deletionStatus'] == 'pending_window' ||
          data['deletionRequestedAt'] != null ||
          data['deletionPurgeAfter'] != null;
      final isDeactivated = data['is_deactivated'] == true ||
          data['account_status'] == 'deactivated';
      if (!isDeactivated && !hasPendingDeletion) {
        return;
      }

      final result =
          await AccountLifecycleService().reactivateAccount(currentUser.uid);
      if (result.success) {
        print('✅ Auto-reactivated account on login for ${currentUser.uid}');
      } else {
        print(
            '❌ Auto-reactivation failed for ${currentUser.uid}: ${result.message}');
      }
    } catch (e) {
      print('❌ Auto-reactivation check failed: $e');
    }
  }

  // static FirebaseStorage storage = FirebaseStorage.instance;

  //for gmail user

  // for checking if user exists or not?

  //get only last message of a specific chat
  // static Stream<QuerySnapshot<Map<String, dynamic>>> getLastMessage(
  //     AcceptedDateData user) {
  //   return firestore
  //       .collection('chats/${getConversationID(user.id!)}/messages/')
  //       .orderBy('sent', descending: true)
  //       .limit(1)
  //       .snapshots();
  // }
  static Future<Map<String, String>> sendPostVideo(
    String chatUserID,
    File videoFile, {
    void Function(UploadTask task)? onVideoUploadTask,
  }) async {
    try {
      // Getting video file extension
      final ext = videoFile.path.split('.').last;

      // Storage file ref with path for video
      final ref = storage.ref().child(
          'videos/$chatUserID/${DateTime.now().toUtc().millisecondsSinceEpoch}.$ext');

        final thumbnailFuture = generateThumbnail(videoFile);

      // Uploading video
        final uploadTask =
          ref.putFile(videoFile, SettableMetadata(contentType: 'video/$ext'));
        onVideoUploadTask?.call(uploadTask);
        await uploadTask;

      // Getting video URL
      final videoUrl = await ref.getDownloadURL();

      // Generate thumbnail
        final thumbnail = await thumbnailFuture;

      // Storage file ref with path for thumbnail
      final thumbnailRef = storage.ref().child(
          'thumbnails/$chatUserID/${DateTime.now().toUtc().millisecondsSinceEpoch}_thumbnail.jpg');

      // Uploading thumbnail
      final thumbnailTask = thumbnailRef.putFile(thumbnail);
      final thumbnailSnapshot = await thumbnailTask.whenComplete(() {});
      final thumbnailUrl = await thumbnailSnapshot.ref.getDownloadURL();

      return {"videoUrl": videoUrl, "thumbnailUrl": thumbnailUrl};
    } on FirebaseException catch (e) {
      if (e.code == 'canceled') {
        throw UploadCancelledException();
      }
      throw Exception('Error uploading video: ${e.message ?? e.code}');
    } catch (e) {
      if (e is UploadCancelledException) {
        rethrow;
      }
      throw Exception('Error uploading video: $e');
    }
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>> getAllMessages(
      ChatUser user) {
    return firestore.collection('messages').doc(user.chatId).snapshots();
  }

  static Future<String> sendPostImage(String chatUserID, File file) async {
    //getting image file extension
    final ext = file.path.split('.').last;

    //storage file ref with path
    final ref = storage.ref().child(
        'images/$chatUserID/${DateTime.now().toUtc().millisecondsSinceEpoch}.$ext');

    //uploading image
    await ref
        .putFile(file, SettableMetadata(contentType: 'image/$ext'))
        .then((p0) {});

    //updating image in firestore database
    final imageUrl = await ref.getDownloadURL();

    return imageUrl;
  }

  static Future<File> generateThumbnail(File videoFile) async {
    final tempDir = await getTemporaryDirectory();

    try {
      final thumbnailPath = await VideoThumbnail.thumbnailFile(
        video: videoFile.path,
        thumbnailPath: tempDir.path,
        imageFormat: ImageFormat.JPEG,
        quality: 75,
        maxWidth: 512,
        timeMs: 1000,
      );

      if (thumbnailPath != null) {
        return File(thumbnailPath);
      }

      throw Exception('Thumbnail generation returned null path');
    } catch (e) {
      print('Error generating thumbnail: $e');
      rethrow;
    }
  }

  // // for getting specific user info
  // static Stream<QuerySnapshot<Map<String, dynamic>>> getUserInfo(
  //     AcceptedDateData chatUser) {
  //   return firestore
  //       .collection('UserChat')
  //       .where('email', isEqualTo: FirebaseAuth.instance.currentUser!.email)
  //       .snapshots(); // Update with your stream
  // }

  // static Future<String?> getConversationID(userEmail, userName) async {
  //   String? id ; bool found = false;
  //   await  firestore
  //       .collection('users')
  //       .doc(FirebaseAuth.instance.currentUser!.email).get().then((value)  async {
  //
  //     try {
  //
  //       List allChats = value["chats"];
  //       allChats.forEach((element) {
  //
  //
  //         if (element['email'] == userEmail){
  //           found = true;
  //           id = element['id'];
  //
  //
  //         }
  //       });
  //       if (found==false){
  //
  //         await FirebaseFirestore.instance.collection("messages").add(
  //             {       "chatMessages" : [],
  //               "users" : [FirebaseAuth.instance.currentUser!.email, userEmail]}
  //         ).then( (value) async {
  //
  //           id = value.id;
  //
  //
  //           print(FirebaseAuth.instance.currentUser!.email);
  //           print(userEmail);
  //           print(userName);
  //
  //           await FirebaseFirestore.instance.collection("users").doc(FirebaseAuth.instance.currentUser!.email).update({
  //             "chats": FieldValue.arrayUnion(
  //                 [{
  //                   "email":userEmail,
  //                   "id":id,
  //                   "name":userName
  //                 }]
  //             )
  //           });
  //           await FirebaseFirestore.instance.collection("users").doc(userEmail).update({
  //             "chats": FieldValue.arrayUnion(
  //                 [{
  //                   "email":FirebaseAuth.instance.currentUser!.email,
  //                   "id":id,
  //                   "name":FirebaseAuth.instance.currentUser!.displayName
  //                 }]
  //             )
  //           });
  //           print("Second");
  //           print(FirebaseAuth.instance.currentUser!.displayName);
  //           print(userEmail);
  //           print(userName);
  //           return id;
  //         }
  //         );
  //       }
  //     } catch(e){
  //       print(e);
  //     }
  //
  //
  //   });
  //   return id;
  // }
  //

  // //update read status of message
  // static Future<void> updateMessageReadStatus(Messges message, AcceptedDateData user) async {
  //   firestore
  //       .collection('messages')
  //       .doc(user.id)
  //       .update({'read': DateTime.now().millisecondsSinceEpoch.toString()});
  // }

  // //delete message
  // static Future<void> deleteMessage(Messges message) async {
  //   await firestore
  //       .collection('chats/${getConversationID(message.toId!)}/messages/')
  //       .doc(message.sent)
  //       .delete();
  //
  //
  // }

//send first msg

  // static Future<void> sendFirstMessage(
  //     AcceptedDateData chatUser, String msg, Typee type) async {
  //   await firestore
  //       .collection('UserChat')
  //       .doc(chatUser.id!+user.uid)
  //       .collection('my_users')
  //       .doc(user.uid)
  //       .set({}).then((value) => sendMessage(chatUser, msg, type));
  // }

// // Old chat image/video methods commented out - replaced by new implementations below
//   static Future<Map<String, String>> sendPostVideo(String chatUserID, File videoFile) async {
//     try {
//       // Getting video file extension
//       final ext = videoFile.path.split('.').last;
//
//       // Storage file ref with path for video
//       final ref = storage.ref().child(
//           'videos/${chatUserID}/${DateTime.now().millisecondsSinceEpoch}.$ext');
//
//       // Uploading video
//       await ref
//           .putFile(videoFile, SettableMetadata(contentType: 'video/$ext'))
//           .then((p0) {
//         log('Data Transferred: ${p0.bytesTransferred / 1000} kb');
//       });
//
//       // Getting video URL
//       final videoUrl = await ref.getDownloadURL();
//
//       // Generate thumbnail
//       final thumbnail = await generateThumbnail(videoFile);
//
//       // Storage file ref with path for thumbnail
//       final thumbnailRef = storage.ref().child(
//           'thumbnails/${chatUserID}/${DateTime.now().millisecondsSinceEpoch}_thumbnail.jpg');
//
//       // Uploading thumbnail
//       final thumbnailTask = thumbnailRef.putFile(thumbnail);
//       final thumbnailSnapshot = await thumbnailTask.whenComplete(() {});
//       final thumbnailUrl = await thumbnailSnapshot.ref.getDownloadURL();
//
//       return {"videoUrl": videoUrl, "thumbnailUrl":thumbnailUrl};
//     } catch (e) {
//       log('Error uploading video: $e');
//       throw Exception('Error uploading video');
//     }
//   }
//
//
//
// // Function to generate thumbnail from video file
//   static Future<File> generateThumbnail(File videoFile) async {
//     // Generate thumbnail using video_thumbnail package
//     final thumbnail = await VideoThumbnail.thumbnailFile(
//       video: videoFile.path,
//       imageFormat: ImageFormat.JPEG,
//       maxWidth: 150, // Specify the width of the thumbnail
//       quality: 25, // Specify the quality of the thumbnail
//     );
//     return File(thumbnail.toString());
//   }
//
//
//
// // for sending message
  static Future<void> sendMessage(ChatUser chatUser, String msg,
      {String? thumbnailUrl}) async {
//
//     // message sending time (also used as id)
//     print("IN SEND MESSAGE");
//     final time = DateTime.now().millisecondsSinceEpoch.toString();
//
//     // message to send
//     final Messges message = Messges(
//       toId: chatUser.email,
//       msg: msg,
//       read: '',
//       type: type,
//       fromId: user.uid,
//       sent: time,
//       thumbnailUrl: thumbnailUrl, // Pass the thumbnailUrl parameter
//     );
//     print(chatUser.id);
//     final ref = firestore
//         .collection('messages');
//     print(message.toJson);
//     await ref.doc(chatUser.id).update(
//         {
//           "chatMessages": FieldValue.arrayUnion([message.toJson( )])
//         }
//     );
//     //.then((value) =>
//     //sendPushNotification(chatUser as AcceptedDateData, type == Typee.text ? msg : 'image'));
//
//     // await ref.doc(time).set(message.toJson()).then((value) =>
//     //     sendPushNotification(chatUser as AcceptedDateData, type == Typee.text ? msg : 'image'));
  }
//

// for sending push notification
// static Future<void> sendPushNotification(
//     AcceptedDateData chatUser, String msg) async {
//   try {
//     final body = {
//       "to": chatUser.id,
//       "notification": {
//         "title": chatUser.name, //our name should be send
//         "body": msg,
//         "android_channel_id": "chats"
//       },
//       "data": {
//         "some_data": "User ID: ${chatUser.id}",
//       },
//     };
//
//   } catch (e) {
//     // log('\nsendPushNotificationE: $e');
//   }
// }

// chats (collection) --> conversation_id (doc) --> messages (collection) --> message (doc)

// useful for getting conversation id
// static String getConversationID(String id) => user.uid.hashCode <= id.hashCode
//     ? '${user.uid}_$id'
//     : '${id}_${user.uid}';

  static Future<void> deletePostImage(String imageUrl) async {
    try {
      // Create a reference to the file to delete
      final ref = storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      throw Exception('Failed to delete image');
    }
  }

  static Future<void> deletePostVideo(
      String videoUrl, String thumbnailUrl) async {
    try {
      // Delete video file
      final videoRef = storage.refFromURL(videoUrl);
      await videoRef.delete();

      // Delete thumbnail file
      final thumbnailRef = storage.refFromURL(thumbnailUrl);
      await thumbnailRef.delete();
    } catch (e) {
      throw Exception('Failed to delete video');
    }
  }

  // Send chat image (for chats/DMs/group chats)
  static Future<String> sendChatImage(String chatUserID, File file) async {
    try {
      // Getting image file extension
      final ext = file.path.split('.').last;

      // Storage file ref with path
      final ref = storage.ref().child(
          'chat_images/$chatUserID/${DateTime.now().toUtc().millisecondsSinceEpoch}.$ext');

      // Uploading image
      await ref.putFile(file, SettableMetadata(contentType: 'image/$ext'));

      // Getting download URL
      final imageUrl = await ref.getDownloadURL();

      return imageUrl;
    } catch (e) {
      throw Exception('Error uploading chat image: $e');
    }
  }

  // Send chat video (for chats/DMs/group chats)
  static Future<Map<String, String>> sendChatVideo(
      String chatUserID, File videoFile) async {
    try {
      // Getting video file extension
      final ext = videoFile.path.split('.').last;

      // Storage file ref with path for video
      final ref = storage.ref().child(
          'chat_videos/$chatUserID/${DateTime.now().toUtc().millisecondsSinceEpoch}.$ext');

      // Uploading video
      await ref.putFile(videoFile, SettableMetadata(contentType: 'video/$ext'));

      // Getting video URL
      final videoUrl = await ref.getDownloadURL();

      // Generate thumbnail
      final thumbnail = await generateThumbnail(videoFile);

      // Storage file ref with path for thumbnail
      final thumbnailRef = storage.ref().child(
          'chat_thumbnails/$chatUserID/${DateTime.now().toUtc().millisecondsSinceEpoch}_thumbnail.jpg');

      // Uploading thumbnail
      final thumbnailTask = thumbnailRef.putFile(thumbnail);
      final thumbnailSnapshot = await thumbnailTask.whenComplete(() {});
      final thumbnailUrl = await thumbnailSnapshot.ref.getDownloadURL();

      return {"videoUrl": videoUrl, "thumbnailUrl": thumbnailUrl};
    } catch (e) {
      throw Exception('Error uploading chat video: $e');
    }
  }

  // Delete chat media
  static Future<void> deleteChatImage(String imageUrl) async {
    try {
      final ref = storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      throw Exception('Failed to delete chat image');
    }
  }

  static Future<void> deleteChatVideo(
      String videoUrl, String thumbnailUrl) async {
    try {
      // Delete video file
      final videoRef = storage.refFromURL(videoUrl);
      await videoRef.delete();

      // Delete thumbnail file
      final thumbnailRef = storage.refFromURL(thumbnailUrl);
      await thumbnailRef.delete();
    } catch (e) {
      throw Exception('Failed to delete chat video');
    }
  }

  /* ----------------------google sign in-------------------------- */
  signinWithGoogle() async {
    final GoogleSignIn googleSignIn = GoogleSignIn(
      scopes: [
        'email',
      ],
      serverClientId:
          '912424781531-vru85aelna5oro0lrnkl11jd49oc74ss.apps.googleusercontent.com',
    );

    try {
      final GoogleSignInAccount? gUser = await googleSignIn.signIn();

      if (gUser == null) {
        // User cancelled sign-in
        print("❌ Google Sign-In cancelled by user");
        return null;
      }

      final GoogleSignInAuthentication gAuth = await gUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: gAuth.accessToken,
        idToken: gAuth.idToken,
      );

      final userCredential = await auth.signInWithCredential(credential);

      final currentUser = auth.currentUser;
      if (currentUser != null) {
        final profileData = <String, dynamic>{
          'uid': currentUser.uid,
          'email': currentUser.email,
          'createdAt': FieldValue.serverTimestamp(),
          'interests': [],
        };

        final displayName = currentUser.displayName?.trim();
        if (displayName != null && displayName.isNotEmpty) {
          profileData['name'] = displayName;
        }

        await firestore
            .collection('humanUsers')
            .doc(currentUser.uid)
            .set(profileData, SetOptions(merge: true));

        // Re-register FCM token after successful Google sign-in
        try {
          await NotificationEventService.reRegisterFCMToken();
        } catch (e) {
          print('❌ Failed to re-register FCM token after Google sign-in: $e');
        }

        await _autoReactivateIfDeactivated(currentUser);
      }

      return userCredential;
    } catch (e) {
      print("❌ Google Sign-In failed: $e");
      return null;
    }
  }

  signinWithApple() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oAuthProvider = OAuthProvider('apple.com').credential(
        idToken: credential.identityToken,
        accessToken: credential.authorizationCode,
      );

      final userCredential = await auth.signInWithCredential(oAuthProvider);

      final currentUser = auth.currentUser;
      if (currentUser != null) {
        final profileData = <String, dynamic>{
          'uid': currentUser.uid,
          'email': currentUser.email,
          'createdAt': FieldValue.serverTimestamp(),
          'interests': [],
        };

        final displayName = currentUser.displayName?.trim();
        if (displayName != null && displayName.isNotEmpty) {
          profileData['name'] = displayName;
        }

        await firestore
            .collection('humanUsers')
            .doc(currentUser.uid)
            .set(profileData, SetOptions(merge: true));

        // Re-register FCM token after successful Apple sign-in
        try {
          await NotificationEventService.reRegisterFCMToken();
        } catch (e) {
          print('❌ Failed to re-register FCM token after Apple sign-in: $e');
        }

        await _autoReactivateIfDeactivated(currentUser);
      }
      return userCredential;
    } catch (e) {
      print("❌ Sign in with Apple failed: $e");
      return null;
    }
  }

  /* ----------------------email sign in-------------------------- */
  static Future<String?> loginOrSignUpWithEmail({
    required String email,
    required String password,
  }) async {
    if (!RegExp(r"^[^@]+@[^@]+\.[^@]+").hasMatch(email)) {
      return 'invalid-email';
    }

    if (password.length < 6) {
      return 'weak-password';
    }

    try {
      await auth.signInWithEmailAndPassword(email: email, password: password);
      print('✅ Login successful for $email');

      await _autoReactivateIfDeactivated(auth.currentUser);

      // Re-register FCM token after successful login
      try {
        await NotificationEventService.reRegisterFCMToken();
      } catch (e) {
        print('❌ Failed to re-register FCM token after login: $e');
      }

      return null;
    } on FirebaseAuthException catch (e) {
      print("❌ Login failed: ${e.code}");

      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        try {
          final credential = await auth.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
          print('✅ Signed up new user: ${credential.user?.uid}');
          return 'signed-up';
        } on FirebaseAuthException catch (e2) {
          print("❌ Sign up failed: ${e2.code}");
          return e2.code;
        }
      }

      return e.code;
    } catch (e) {
      print("❌ Unexpected error: $e");
      return 'unexpected-error';
    }
  }
}
