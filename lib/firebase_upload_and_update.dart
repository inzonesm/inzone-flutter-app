inzone-flutter-app/lib/firebase_upload_and_update.dart
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';

/// Uploads an image file to Firebase Storage and updates the profile_picture_url
/// field of the corresponding document in the popularCharacters Firestore collection.
///
/// [imageFile] is the local image file to upload.
/// [characterId] is the Firestore document ID of the character to update.
Future<void> uploadProfilePictureAndUpdateCharacter({
  required File imageFile,
  required String characterId,
}) async {
  try {
    // 1. Upload image to Firebase Storage
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('profile_pictures/$characterId.jpg');
    await storageRef.putFile(imageFile);

    // 2. Get the download URL
    final downloadUrl = await storageRef.getDownloadURL();

    // 3. Update Firestore document
    final docRef = FirebaseFirestore.instance
        .collection('popularCharacters')
        .doc(characterId);
    await docRef.update({'profile_picture_url': downloadUrl});

    print('Profile picture uploaded and Firestore updated!');
  } catch (e) {
    print('Error uploading profile picture: $e');
    // You may want to handle errors more gracefully in production
  }
}
