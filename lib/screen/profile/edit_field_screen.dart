import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:inzone/services/inzone_database.dart';
import 'package:inzone/theme/app_colors.dart';
import 'package:toasty_box/toast_service.dart';

enum FieldType {
  name,
  username,
  bio,
}

class EditFieldScreen extends StatefulWidget {
  final String userId;
  final String initialValue;
  final FieldType fieldType;

  const EditFieldScreen({
    super.key,
    required this.userId,
    required this.initialValue,
    required this.fieldType,
  });

  @override
  State<EditFieldScreen> createState() => _EditFieldScreenState();
}

class _EditFieldScreenState extends State<EditFieldScreen> {
  late TextEditingController _controller;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (_controller.text.isEmpty) {
      ToastService.showToast(
        context,
        backgroundColor: Theme.of(context).canvasColor,
        shadowColor: Colors.transparent,
        leading: const Icon(
          FeatherIcons.xCircle,
          color: Colors.redAccent,
        ),
        message: 'This field cannot be empty',
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Verify authentication status first
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception(
            "You are not currently logged in. Please sign in again.");
      }

      // Create profile data map based on field type
      Map<String, dynamic> profileData = {};

      switch (widget.fieldType) {
        case FieldType.name:
          profileData['name'] = _controller.text;
          break;
        case FieldType.username:
          profileData['username'] = _controller.text;
          break;
        case FieldType.bio:
          profileData['bio'] = _controller.text;
          break;
      }

      // Update profile in database
      await InZoneDatabase.updateUserProfileData(widget.userId, profileData);

      if (mounted) {
        ToastService.showToast(
          context,
          backgroundColor: Theme.of(context).canvasColor,
          shadowColor: Colors.transparent,
          leading: const Icon(
            FeatherIcons.checkCircle,
            color: Colors.greenAccent,
          ),
          message: 'Updated successfully',
        );

        // Return true to indicate successful update and trigger profile refresh
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Error updating: ';

        // Handle specific error types
        if (e.toString().contains('not authenticated') ||
            e.toString().contains('Authentication failed')) {
          errorMessage =
              'Authentication error. Please log out and sign in again.';
        } else if (e.toString().contains('network')) {
          errorMessage = 'Network error. Please check your connection.';
        } else {
          errorMessage += e.toString().replaceAll('Exception: ', '');
        }
        ToastService.showToast(
          context,
          backgroundColor: Theme.of(context).canvasColor,
          shadowColor: Colors.transparent,
          leading: Icon(
            errorMessage.contains('success')
                ? FeatherIcons.checkCircle
                : FeatherIcons.xCircle,
            color: errorMessage.contains('success')
                ? Colors.greenAccent
                : Colors.redAccent,
          ),
          message: errorMessage,
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

  String _getTitle() {
    switch (widget.fieldType) {
      case FieldType.name:
        return 'Name';
      case FieldType.username:
        return 'Username';
      case FieldType.bio:
        return 'Bio';
    }
  }

  String _getHintText() {
    switch (widget.fieldType) {
      case FieldType.name:
        return 'Enter your name';
      case FieldType.username:
        return 'Enter your username';
      case FieldType.bio:
        return 'Tell something about yourself...';
    }
  }

  int _getMaxLines() {
    return widget.fieldType == FieldType.bio ? 3 : 1;
  }

  int? _getMaxLength() {
    return widget.fieldType == FieldType.bio ? 150 : null;
  }

  Widget _buildProfilePictureSection() {
    // Removed profile picture section for name field
    return const SizedBox.shrink();
  }

  Widget _buildUsernameInfo() {
    if (widget.fieldType != FieldType.username) return const SizedBox.shrink();

    final textColor = Theme.of(context).brightness == Brightness.dark
        ? AppColors.darkTextColor.withOpacity(0.7)
        : AppColors.lightTextColor.withOpacity(0.7);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "You can change your username back to ${widget.initialValue} within 14 days, as long as it hasn't been taken by someone else.",
            style: TextStyle(
              color: textColor,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 15),
          Text(
            "Username changes are limited to 5 times every 30 days to prevent abuse.",
            style: TextStyle(
              color: textColor,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 15),
          Text(
            "Choose carefully - your username is visible to everyone in the InZone community and becomes part of your unique profile URL.",
            style: TextStyle(
              color: textColor,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameInfo() {
    if (widget.fieldType != FieldType.name) return const SizedBox.shrink();

    final textColor = Theme.of(context).brightness == Brightness.dark
        ? AppColors.darkTextColor.withOpacity(0.7)
        : AppColors.lightTextColor.withOpacity(0.7);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Your display name helps people recognize you in the InZone community.",
            style: TextStyle(
              color: textColor,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 15),
          Text(
            "You can use your real name, nickname, or any name you prefer to go by.",
            style: TextStyle(
              color: textColor,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 15),
          Text(
            "Names that violate our community guidelines may be removed.",
            style: TextStyle(
              color: textColor,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBioInfo() {
    if (widget.fieldType != FieldType.bio) return const SizedBox.shrink();

    final textColor = Theme.of(context).brightness == Brightness.dark
        ? AppColors.darkTextColor.withOpacity(0.7)
        : AppColors.lightTextColor.withOpacity(0.7);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Your bio is a short introduction that appears on your profile page.",
            style: TextStyle(
              color: textColor,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 15),
          Text(
            "You can share your interests, location, or anything else you'd like the community to know about you.",
            style: TextStyle(
              color: textColor,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 15),
          Text(
            "Keep it friendly and respectful - your bio is visible to everyone in the InZone community.",
            style: TextStyle(
              color: textColor,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor =
        isDarkMode ? AppColors.darkBackground : AppColors.lightBackground;
    final surfaceColor =
        isDarkMode ? AppColors.darkSurfaceColor : AppColors.lightSurfaceColor;
    final textColor =
        isDarkMode ? AppColors.darkTextColor : AppColors.lightTextColor;
    const accentColor = AppColors.primaryBlue;
    final dividerColor =
        isDarkMode ? AppColors.darkDividerColor : AppColors.lightDividerColor;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => context.pop(false),
        ),
        title: Text(
          _getTitle(),
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveChanges,
            child: const Text(
              'Done',
              style: TextStyle(
                color: accentColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator(color: accentColor))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildProfilePictureSection(),
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: dividerColor),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          style: TextStyle(color: textColor),
                          maxLines: _getMaxLines(),
                          maxLength: _getMaxLength(),
                          decoration: InputDecoration(
                            hintText: _getHintText(),
                            hintStyle:
                                TextStyle(color: textColor.withOpacity(0.5)),
                            border: InputBorder.none,
                            counterText: "",
                          ),
                        ),
                      ),
                      if (_controller.text.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _controller.clear();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: dividerColor,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close,
                              color: textColor,
                              size: 16,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                _buildNameInfo(),
                _buildUsernameInfo(),
                _buildBioInfo(),
              ],
            ),
    );
  }
}
