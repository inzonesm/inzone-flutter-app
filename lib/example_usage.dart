inzone-flutter-app/lib/example_usage.dart
```
```inzone-flutter-app/lib/example_usage.dart#L1-17
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Uploads an image to Firebase Storage and updates the profile_picture_url
/// field in the popularCharacters Firestore collection.
Future<void> uploadProfilePictureAndUpdateCharacter({
  required File imageFile,
  required String characterId,
}) async {
  try {
    // Upload image to Firebase Storage
    final storageRef = FirebaseStorage.instance.ref().child('profile_pictures/$characterId.jpg');
    await storageRef.putFile(imageFile);

    // Get the download URL
    final downloadUrl = await storageRef.getDownloadURL();

    // Update Firestore document
    final docRef = FirebaseFirestore.instance.collection('popularCharacters').doc(characterId);
    await docRef.update({'profile_picture_url': downloadUrl});

    print('Profile picture uploaded and Firestore updated!');
  } catch (e) {
    print('Error uploading profile picture: $e');
    // Handle error (show snackbar, etc.)
  }
}

// Example usage:
// File imageFile = File('/path/to/image.jpg');
// String characterId = 'CHARACTER_DOC_ID';
// await uploadProfilePictureAndUpdateCharacter(
//   imageFile: imageFile,
//   characterId: characterId,
// );
