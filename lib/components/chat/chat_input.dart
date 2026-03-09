import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

class ChatInput extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final String hintText;
  final ScrollController? scrollController;
  final String receiverAvatarUrl;
  final String receiverAvatarId;
  final bool isGroupChat;
  final Function(File)? onImagePicked;
  final Function(File)? onVideoPicked;
  final File? pendingImage;
  final File? pendingVideo;
  final VoidCallback? onClearMedia;

  const ChatInput({
    super.key,
    required this.controller,
    required this.onSend,
    this.hintText = ' Start a conversation',
    this.scrollController,
    this.receiverAvatarUrl = "",
    this.receiverAvatarId = "",
    this.isGroupChat = false,
    this.onImagePicked,
    this.onVideoPicked,
    this.pendingImage,
    this.pendingVideo,
    this.onClearMedia,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  bool _isTextEmpty = true;

  @override
  void initState() {
    super.initState();
    _isTextEmpty = widget.controller.text.isEmpty;
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) {
      setState(() {
        _isTextEmpty = widget.controller.text.isEmpty;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasMedia = widget.pendingImage != null || widget.pendingVideo != null;
    
    return Container(
      color: Theme.of(context).canvasColor,
      child: Padding(
        padding:
            const EdgeInsets.only(left: 10.0, right: 10, bottom: 30, top: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Media preview
            if (hasMedia)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey.shade800
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  children: [
                    if (widget.pendingImage != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          widget.pendingImage!,
                          height: 150,
                          fit: BoxFit.cover,
                        ),
                      ),
                    if (widget.pendingVideo != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          height: 150,
                          child: _VideoPreview(videoFile: widget.pendingVideo!),
                        ),
                      ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: widget.onClearMedia,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
            // Media buttons (image and video)
            if (widget.onImagePicked != null || widget.onVideoPicked != null)
              Row(
                children: [
                  if (widget.onImagePicked != null)
                    IconButton(
                      icon: Icon(
                        FeatherIcons.image,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey.shade400
                            : Colors.blue.shade600,
                        size: 24,
                      ),
                      onPressed: () async {
                        final ImagePicker picker = ImagePicker();
                        final XFile? image = await picker.pickImage(
                          source: ImageSource.gallery,
                          imageQuality: 90,
                        );
                        if (image != null && widget.onImagePicked != null) {
                          widget.onImagePicked!(File(image.path));
                        }
                      },
                    ),
                  if (widget.onVideoPicked != null)
                    IconButton(
                      icon: Icon(
                        FeatherIcons.video,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey.shade400
                            : Colors.blue.shade600,
                        size: 24,
                      ),
                      onPressed: () async {
                        final ImagePicker picker = ImagePicker();
                        final XFile? video = await picker.pickVideo(
                          source: ImageSource.gallery,
                          maxDuration: const Duration(minutes: 5),
                        );
                        if (video != null && widget.onVideoPicked != null) {
                          widget.onVideoPicked!(File(video.path));
                        }
                      },
                    ),
                ],
              ),
            Expanded(
              child: Scrollbar(
                controller: widget.scrollController,
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 100),
                  child: TextFormField(
                    scrollController: widget.scrollController,
                    cursorColor: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey.shade400
                        : Colors.blue.shade600,
                    controller: widget.controller,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    onFieldSubmitted:
                        _isTextEmpty ? null : (_) => widget.onSend(),
                    textInputAction: TextInputAction.send,
                    decoration: InputDecoration(
                      contentPadding:
                          const EdgeInsets.only(left: 20, right: 10),
                      border: InputBorder.none,
                      hintText: widget.hintText,
                      hintStyle: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey.shade400
                            : Colors.blue.shade600,
                      ),
                      filled: true,
                      fillColor: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey.shade800
                          : Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.2),
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(
                          color: Colors.transparent,
                        ),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(
                          color: Colors.transparent,
                        ),
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            if (!widget.isGroupChat)
              MaterialButton(
                minWidth: 45,
                height: 50,
                elevation: 0,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey.shade800
                    : Theme.of(context).colorScheme.primary.withOpacity(0.8),
                shape: const CircleBorder(),
                onPressed: (_isTextEmpty && !hasMedia)
                    ? () => context.push('/chat/voice', extra: {
                          'avatarUrl': widget.receiverAvatarUrl,
                          'avatarId': widget.receiverAvatarId,
                        })
                    : widget.onSend,
                child: Center(
                  child: Icon(
                    (_isTextEmpty && !hasMedia) ? Icons.mic : FeatherIcons.arrowUp,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            if (widget.isGroupChat)
              MaterialButton(
                minWidth: 45,
                height: 50,
                elevation: 0,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey.shade800
                    : Theme.of(context).colorScheme.primary.withOpacity(0.8),
                shape: const CircleBorder(),
                onPressed: widget.onSend,
                child: const Center(
                  child: Icon(
                    FeatherIcons.arrowUp,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
          ],
        ),
          ],
        ),
      ),
    );
  }
}

// Video preview widget
class _VideoPreview extends StatefulWidget {
  final File videoFile;

  const _VideoPreview({required this.videoFile});

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(widget.videoFile)
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _initialized = true;
          });
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: VideoPlayer(_controller),
        ),
        Icon(
          Icons.play_circle_outline,
          size: 50,
          color: Colors.white.withOpacity(0.8),
        ),
      ],
    );
  }
}