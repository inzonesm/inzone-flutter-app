import 'dart:io';
import 'package:colorful_safe_area/colorful_safe_area.dart';
import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:inzone/components/ui/button.dart';
import 'package:inzone/router/routes.dart';

class AICharacterPromptScreen extends StatefulWidget {
  const AICharacterPromptScreen({super.key});

  @override
  State<AICharacterPromptScreen> createState() =>
      _AICharacterPromptScreenState();
}

class _AICharacterPromptScreenState extends State<AICharacterPromptScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  File? _characterImage;
  final bool _isUploading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedImage = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );

    if (pickedImage != null) {
      setState(() {
        _characterImage = File(pickedImage.path);
      });
    }
  }

  void _createCharacter() {
    // Add character creation logic here
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a character name')),
      );
      return;
    }

    // Navigate to model selection screen with input data
    context.push(
      Routes.createAICharacterSelect,
      extra: {
        'prompt': _descriptionController.text.trim(),
        'name': _nameController.text.trim(),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColorfulSafeArea(
      color: Theme.of(context).dialogBackgroundColor,
      child: Scaffold(
        backgroundColor: Theme.of(context).dialogBackgroundColor,
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Create an AI Character',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: Icon(
                        FeatherIcons.x,
                        color: Theme.of(context).iconTheme.color,
                        size: 28,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                Text(
                  'Character Name',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Theme.of(context).dividerColor,
                    ),
                  ),
                  child: TextField(
                    controller: _nameController,
                    cursorColor: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black,
                    decoration: const InputDecoration(
                      hintText: 'Enter character name',
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Text(
                      'Character Description',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(Required)',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Theme.of(context).dividerColor,
                    ),
                  ),
                  child: TextField(
                    controller: _descriptionController,
                    cursorColor: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      hintText: 'Enter Your Description',
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Row(
                //   children: [
                //     Text(
                //       'Character Image',
                //       style: TextStyle(
                //         fontSize: 16,
                //         fontWeight: FontWeight.w500,
                //         color: Theme.of(context).textTheme.bodyLarge?.color,
                //       ),
                //     ),
                //     const SizedBox(width: 8),
                //     Text(
                //       '(Optional)',
                //       style: TextStyle(
                //         fontSize: 14,
                //         color: Theme.of(context).textTheme.bodyMedium?.color,
                //       ),
                //     ),
                //   ],
                // ),
                // const SizedBox(height: 16),
                // GestureDetector(
                //   onTap: _pickImage,
                //   child: Container(
                //     height: 200,
                //     width: double.infinity,
                //     decoration: BoxDecoration(
                //       color: Theme.of(context).cardColor,
                //       borderRadius: BorderRadius.circular(10),
                //       border: Border.all(
                //         color: Theme.of(context).dividerColor,
                //       ),
                //     ),
                //     child: _characterImage != null
                //         ? ClipRRect(
                //             borderRadius: BorderRadius.circular(10),
                //             child: Image.file(
                //               _characterImage!,
                //               fit: BoxFit.cover,
                //             ),
                //           )
                //         : Column(
                //             mainAxisAlignment: MainAxisAlignment.center,
                //             children: [
                //               Icon(
                //                 FeatherIcons.image,
                //                 size: 48,
                //                 color: Theme.of(context).iconTheme.color,
                //               ),
                //               const SizedBox(height: 8),
                //               Text(
                //                 'Tap to add an image',
                //                 style: TextStyle(
                //                   color: Theme.of(context)
                //                       .textTheme
                //                       .bodyMedium
                //                       ?.color,
                //                 ),
                //               ),
                //             ],
                //           ),
                //   ),
                // ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Button(
            text: 'Create AI Character',
            onPressed: _createCharacter,
          ),
        ),
      ),
    );
  }
}
