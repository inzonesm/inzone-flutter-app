import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:colorful_safe_area/colorful_safe_area.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:inzone/router/routes.dart';
import 'package:inzone/theme/app_colors.dart';
import 'package:toasty_box/toast_service.dart';

class ProfileScreen extends StatefulWidget {
  final String email;
  const ProfileScreen({super.key, required this.email});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  File? _profileImageFile;
  bool _isSaving = false;

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _profileImageFile = File(picked.path);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty) {
      ToastService.showToast(
        context,
        backgroundColor: Theme.of(context).canvasColor,
        shadowColor: Colors.transparent,
        leading: const Icon(
          FeatherIcons.xCircle,
          color: Colors.redAccent,
        ),
        message: 'Please enter your name.',
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Center(
            child: Container(
              width: 100, // Adjust as needed
              height: 100, // Adjust as needed
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(100), // Adjust as needed
              ),
              child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(
                    color: Theme.of(context).colorScheme.outline,
                  )),
            ),
          ),
        );
      },
    );

    setState(() {
      _isSaving = true;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser!;
      print("ProfileScreen - Saving profile for user: ${currentUser.uid}");

      String? profileImageUrl;
      if (_profileImageFile != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('profile_pictures/${currentUser.uid}.jpg');
        await ref.putFile(_profileImageFile!);
        profileImageUrl = await ref.getDownloadURL();
        print("ProfileScreen - Uploaded profile image: $profileImageUrl");
      }

      await FirebaseFirestore.instance
          .collection('humanUsers')
          .doc(currentUser.uid)
          .update({
        'profilePicture': profileImageUrl ?? "",
        'name': _nameController.text.trim(),
        'username': _nameController.text.trim().toLowerCase(),
      });

      print(
          "ProfileScreen - Profile saved successfully, navigating to interests screen");

      if (mounted) {
        Navigator.of(context).pop();

        print(
            "ProfileScreen - Navigating to: ${Routes.interestsWithEmail(widget.email)}");
        context.go(Routes.interestsWithEmail(widget.email));
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
      }

      print('ProfileScreen - Error saving profile: $e');
      ToastService.showToast(
        context,
        backgroundColor: Theme.of(context).canvasColor,
        shadowColor: Colors.transparent,
        leading: const Icon(
          FeatherIcons.xCircle,
          color: Colors.redAccent,
        ),
        message: 'Failed to save profile. Please try again.',
      );
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColorfulSafeArea(
      color: Theme.of(context).canvasColor,
      child: Scaffold(
        backgroundColor: Theme.of(context).canvasColor,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Theme.of(context).canvasColor,
          elevation: 0,
          title: Text(
            "Create Your Profile",
            style: Theme.of(context).textTheme.titleLarge,
          ),
          centerTitle: true,
          iconTheme: Theme.of(context).iconTheme,
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    "Please select a profile picture and enter your name.",
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 40),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: CircleAvatar(
                        radius: 120,
                        backgroundColor: Colors.grey[300],
                        backgroundImage: _profileImageFile != null
                            ? FileImage(_profileImageFile!)
                            : null,
                        child: _profileImageFile == null
                            ? const Icon(Icons.person,
                                size: 80, color: Colors.white)
                            : null,
                      ),
                    ),
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).cardColor,
                        ),
                        child: IconButton(
                          icon: Icon(
                            FeatherIcons.camera,
                            color:
                                Theme.of(context).brightness == Brightness.light
                                    ? Colors.black
                                    : Colors.white,
                          ),
                          onPressed: _pickImage,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8.0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12.0,
                    vertical: 8.0,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _nameController,
                    style: Theme.of(context).textTheme.bodyLarge,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Enter your name',
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: Padding(
          padding:
              const EdgeInsets.only(left: 15, right: 15, bottom: 15, top: 15),
          child: GestureDetector(
            onTap: () {
              if (!_isSaving) {
                _saveProfile();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              height: 60,
              width: MediaQuery.of(context).size.width - 80,
              decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(20)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Next',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
