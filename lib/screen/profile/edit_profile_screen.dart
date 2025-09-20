import 'dart:io';
import 'package:colorful_safe_area/colorful_safe_area.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:inzone/components/ui/appbar.dart';
import 'package:inzone/screen/profile/edit_field_screen.dart';
import 'package:inzone/services/inzone_database.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:inzone/router/routes.dart';
import 'package:inzone/theme/app_colors.dart';
import 'package:toasty_box/toast_service.dart';

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
  late String _name;
  late String _username;
  late String _bio;
  bool _isImageLoading = false;
  String _profileImageUrl = '';
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  bool _hasChanges = false; // Track if any changes were made

  @override
  void initState() {
    super.initState();
    _name = widget.initialName;
    _username = widget.initialUsername;
    _bio = widget.initialBio;
    _loadUserProfileImage();
  }

  Future<void> _loadUserProfileImage() async {
    final userData = await InZoneDatabase.getUserProfile(widget.userId);
    if (userData != null && mounted) {
      setState(() {
        _profileImageUrl = userData['profilePicture'] ?? "";
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (image != null) {
      setState(() {
        _imageFile = File(image.path);
        _isImageLoading = true;
      });

      await _saveProfileImage();
    }
  }

  Future<String?> _uploadProfileImage() async {
    if (_imageFile == null) return null;

    try {
      // Get file extension
      final ext = _imageFile!.path.split('.').last;

      // Create a unique filename
      final String fileName =
          '${widget.userId}_${DateTime.now().toUtc().millisecondsSinceEpoch}.$ext';

      // Create reference to storage location
      final ref = _storage.ref().child('profile_pictures/$fileName');

      // Upload file
      await ref.putFile(
          _imageFile!, SettableMetadata(contentType: 'image/$ext'));

      // Get download URL
      final imageUrl = await ref.getDownloadURL();
      return imageUrl;
    } catch (e) {
      print('Error uploading profile image: $e');
      return null;
    }
  }

  Future<void> _saveProfileImage() async {
    try {
      String? newProfileImageUrl = await _uploadProfileImage();

      if (newProfileImageUrl != null) {
        Map<String, dynamic> profileData = {
          'profilePicture': newProfileImageUrl,
        };

        await InZoneDatabase.updateUserProfileData(widget.userId, profileData);

        if (mounted) {
          ToastService.showToast(
            context,
            backgroundColor: Theme.of(context).canvasColor,
            shadowColor: Colors.transparent,
            leading: const Icon(
              Icons.check_circle,
              color: Colors.greenAccent,
            ),
            message: 'Profile picture updated successfully',
          );

          setState(() {
            _profileImageUrl = newProfileImageUrl;
            _imageFile = null;
            _hasChanges = true; // Mark that changes were made
            debugPrint('Profile image updated, _hasChanges set to true');
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ToastService.showToast(
          context,
          backgroundColor: Theme.of(context).canvasColor,
          shadowColor: Colors.transparent,
          leading: const Icon(
            Icons
                .error_outline, // or Icons.check_circle, Icons.warning_amber_rounded, etc.
            color: Colors.redAccent,
          ),
          message: 'Error updating profile: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isImageLoading = false;
        });
      }
    }
  }

  Future<void> _editField(FieldType type) async {
    String initialValue = '';
    switch (type) {
      case FieldType.name:
        initialValue = _name;
        break;
      case FieldType.username:
        initialValue = _username;
        break;
      case FieldType.bio:
        initialValue = _bio;
        break;
    }
    print("HALALALALAL");
    print(widget.userId);
    print(initialValue);
    print(type);
    print("HALALALALAL");

    // Convert enum to string for path parameter
    String fieldTypeStr;
    switch (type) {
      case FieldType.username:
        fieldTypeStr = 'username';
        break;
      case FieldType.bio:
        fieldTypeStr = 'bio';
        break;
      case FieldType.name:
        fieldTypeStr = 'name';
        break;
    }

    final result = await context.push<bool>(
      Routes.editFieldPath(fieldTypeStr),
      extra: {
        'userId': widget.userId,
        'initialValue': initialValue,
      },
    );

    if (result == true) {
      // Refresh user data
      final userData = await InZoneDatabase.getUserProfile(widget.userId);
      if (userData != null && mounted) {
        setState(() {
          _name = userData['name'] ?? userData['Name'] ?? _name;
          _username = userData['username'] ?? userData['Username'] ?? _username;
          _bio = userData['bio'] ?? userData['Bio'] ?? _bio;
          _profileImageUrl = userData['profilePicture'] ??
              userData['ProfilePicture'] ??
              _profileImageUrl;
          _hasChanges = true; // Mark that changes were made
          debugPrint('Field updated, _hasChanges set to true');
        });
      }
    }
  }

  Widget _buildProfilePicture() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    const accentColor = AppColors.primaryBlue;
    final borderColor =
        isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300;
    final surfaceColor =
        isDarkMode ? AppColors.darkSurfaceColor : AppColors.lightSurfaceColor;

    return Container(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: GestureDetector(
              onTap: _isImageLoading ? null : _pickImage,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: borderColor, width: 1),
                      color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                    ),
                    child: _isImageLoading
                        ? Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(60),
                                child: _imageFile != null
                                    ? Image.file(
                                        _imageFile!,
                                        fit: BoxFit.cover,
                                      )
                                    : _profileImageUrl.isNotEmpty
                                        ? Image.network(
                                            _profileImageUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    Icon(Icons.account_circle,
                                                        size: 120,
                                                        color: Colors.grey
                                                            .withOpacity(0.5)),
                                          )
                                        : Icon(Icons.account_circle,
                                            size: 120,
                                            color:
                                                Colors.grey.withOpacity(0.5)),
                              ),
                              Positioned(
                                right: 10,
                                top: 10,
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(60),
                            child: _imageFile != null
                                ? Image.file(
                                    _imageFile!,
                                    fit: BoxFit.cover,
                                  )
                                : _profileImageUrl.isNotEmpty
                                    ? Image.network(
                                        _profileImageUrl,
                                        fit: BoxFit.cover,
                                        loadingBuilder:
                                            (context, child, loadingProgress) {
                                          if (loadingProgress == null)
                                            return child;
                                          return Stack(
                                            children: [
                                              Opacity(
                                                opacity: 0.5,
                                                child: Container(
                                                  color: Colors.grey[800],
                                                  width: 120,
                                                  height: 120,
                                                ),
                                              ),
                                              Positioned(
                                                right: 10,
                                                top: 10,
                                                child: Container(
                                                  width: 24,
                                                  height: 24,
                                                  decoration: BoxDecoration(
                                                    color: Colors.black
                                                        .withOpacity(0.5),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child:
                                                      CircularProgressIndicator(
                                                    color: Colors.white,
                                                    strokeWidth: 2,
                                                    value: loadingProgress
                                                                .expectedTotalBytes !=
                                                            null
                                                        ? loadingProgress
                                                                .cumulativeBytesLoaded /
                                                            loadingProgress
                                                                .expectedTotalBytes!
                                                        : null,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                Icon(Icons.account_circle,
                                                    size: 120,
                                                    color: Colors.grey
                                                        .withOpacity(0.5)),
                                      )
                                    : Icon(Icons.account_circle,
                                        size: 120,
                                        color: Colors.grey.withOpacity(0.5)),
                          ),
                  ),
                  if (!_isImageLoading)
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: accentColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: surfaceColor, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 3,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.photo_camera,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _isImageLoading ? null : _pickImage,
            child: Text(
              "Change Profile Photo",
              style: TextStyle(
                color: _isImageLoading ? Colors.grey : accentColor,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileItem({
    required String label,
    required String value,
    required FieldType type,
    int maxLines = 1,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDarkMode ? AppColors.darkTextColor : AppColors.lightTextColor;
    final surfaceColor =
        isDarkMode ? AppColors.darkSurfaceColor : AppColors.lightSurfaceColor;

    return GestureDetector(
      onTap: () => _editField(type),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: textColor.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        value.isEmpty ? "Not set" : value,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: value.isEmpty ? Colors.grey : textColor,
                        ),
                        maxLines: maxLines,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              Icon(
                Icons.chevron_right,
                color: Colors.grey.withOpacity(0.7),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor =
        isDarkMode ? AppColors.darkBackground : AppColors.lightBackground;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          debugPrint('EditProfileScreen popping with _hasChanges: $_hasChanges');
          Navigator.of(context).pop(_hasChanges);
        }
      },
      child: ColorfulSafeArea(
        topColor: backgroundColor,
        left: false,
        right: false,
        top: true,
        bottom: false,
        child: Scaffold(
          backgroundColor: backgroundColor,
          appBar: CustomAppBar(
            isHome: true,
            isSettings: true,
            isImage: false,
            title: "Edit Profile",
            profileImageUrl: null,
            onSearchTap: null,
            onBackTap: () {
              debugPrint('EditProfileScreen back button tapped, _hasChanges: $_hasChanges');
              Navigator.of(context).pop(_hasChanges);
            },
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildProfilePicture(),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildProfileItem(
                        label: "Name",
                        value: _name,
                        type: FieldType.name,
                      ),
                      _buildProfileItem(
                        label: "Username",
                        value: _username,
                        type: FieldType.username,
                      ),
                      _buildProfileItem(
                        label: "Bio",
                        value: _bio,
                        type: FieldType.bio,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
