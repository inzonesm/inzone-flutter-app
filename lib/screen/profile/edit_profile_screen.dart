import 'package:colorful_safe_area/colorful_safe_area.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inzone/components/ui/appbar.dart';
import 'package:random_avatar/random_avatar.dart';
import 'package:inzone/services/inzone_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EditProfileScreen extends StatefulWidget {
  final String userId;
  final String initialName;
  final String initialUsername;
  final String initialBio;

  const EditProfileScreen({
    super.key,
    required this.userId,
    required this.initialName,
    required this.initialUsername,
    required this.initialBio,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  late TextEditingController _bioController;
  bool _isSaving = false;
  String _currentUsername = '';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _usernameController = TextEditingController(text: widget.initialUsername);
    _bioController = TextEditingController(text: widget.initialBio);
    _currentUsername = widget.initialUsername;

    // Remove the listener as we'll use onChanged instead
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.isEmpty || _usernameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and username cannot be empty')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Update Firebase Auth display name
      await FirebaseAuth.instance.currentUser
          ?.updateDisplayName(_nameController.text);

      // Create profile data map
      Map<String, dynamic> profileData = {
        'name': _nameController.text,
        'username': _usernameController.text,
        'bio': _bioController.text,
      };

      // Update profile in database
      await InZoneDatabase.updateUserProfileData(widget.userId, profileData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );

        // Return true to indicate successful update and trigger profile refresh
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Widget buildCupertinoInput(
      {required String label,
      String? placeholder,
      TextEditingController? controller,
      int maxLines = 1,
      int? maxLength,
      required ValueChanged<String> onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey[100] ?? Colors.grey),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                spreadRadius: 2,
                blurRadius: 5,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(10),
          constraints: maxLines > 1
              ? const BoxConstraints(minHeight: 120)
              : const BoxConstraints(),
          child: CupertinoTextField.borderless(
            controller: controller,
            placeholder: placeholder,
            placeholderStyle: const TextStyle(color: Colors.grey),
            style: const TextStyle(color: Colors.black),
            cursorColor: Colors.black,
            maxLines: maxLines,
            maxLength: maxLength,
            clearButtonMode: OverlayVisibilityMode.editing,
            onChanged: (value) {
              if (controller != null) {
                // Trigger rebuild to update length counter if needed
                (controller as dynamic).notifyListeners();
              }
              onChanged(value);
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColorfulSafeArea(
      topColor: Theme.of(context).canvasColor,
      left: false,
      right: false,
      top: true,
      bottom: false,
      child: Scaffold(
        backgroundColor: Theme.of(context).canvasColor,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: CustomAppBar(
              isImage: false,
              isSettings: true,
              isHome: true,
              title: "Edit Profile",
              userPoints: "100",
              onSearchTap: () {},
              onProfileTap: () {},
              onPointsTap: () {},
            ),
          ),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar that changes based on username
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 80,
                        child: RandomAvatar(
                          _currentUsername.isNotEmpty
                              ? _currentUsername
                              : 'user',
                          height: 160,
                          width: 160,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Avatar changes based on username",
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                buildCupertinoInput(
                  label: "Name",
                  placeholder: "Enter your name",
                  controller: _nameController,
                  maxLines: 1,
                  onChanged: (value) {
                    // Update avatar on every keystroke
                    setState(() {
                      _currentUsername = value;
                    });
                  },
                ),
                const SizedBox(height: 20),
                buildCupertinoInput(
                  label: "User Name",
                  placeholder: "Enter your message",
                  controller: _usernameController,
                  maxLines: 1,
                  onChanged: (value) {
                    // Update avatar on every keystroke
                    setState(() {
                      _currentUsername = value;
                    });
                  },
                ),

                const SizedBox(height: 20),
                buildCupertinoInput(
                  label: "Bio",
                  placeholder: "Enter your bio",
                  controller: _bioController,
                  maxLines: 4,
                  onChanged: (value) {
                    // Update avatar on every keystroke
                    setState(() {
                      _currentUsername = value;
                    });
                  },
                ),
                const SizedBox(height: 40),
                // // Save button
                // SizedBox(
                //   width: double.infinity,
                //   height: 50,
                //   child: ElevatedButton(
                //     onPressed: _isSaving ? null : _saveProfile,
                //     style: ElevatedButton.styleFrom(
                //       backgroundColor: Colors.blue,
                //       foregroundColor: Colors.white,
                //       shape: RoundedRectangleBorder(
                //         borderRadius: BorderRadius.circular(10),
                //       ),
                //     ),
                //     child: _isSaving
                //         ? const CircularProgressIndicator(color: Colors.white)
                //         : const Text(
                //             'Save Changes',
                //             style: TextStyle(
                //               fontSize: 16,
                //               fontWeight: FontWeight.bold,
                //             ),
                //           ),
                //   ),
                // ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: Padding(
          padding:
              const EdgeInsets.only(left: 15, right: 15, bottom: 30, top: 15),
          child: GestureDetector(
            onTap: _isSaving ? null : _saveProfile,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              height: 60,
              width: MediaQuery.of(context).size.width - 80,
              decoration: BoxDecoration(
                  color: Colors.blueAccent,
                  borderRadius: BorderRadius.circular(20)),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'DONE',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
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
