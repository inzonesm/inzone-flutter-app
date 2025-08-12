import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:go_router/go_router.dart';

class ChatInput extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final String hintText;
  final ScrollController? scrollController;
  final String receiverAvatarUrl;
  final String receiverAvatarId;
  final bool isGroupChat;

  const ChatInput({
    super.key,
    required this.controller,
    required this.onSend,
    this.hintText = ' Start a conversation',
    this.scrollController,
    this.receiverAvatarUrl = "",
    this.receiverAvatarId = "",
    this.isGroupChat = false,
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
    return Container(
      color: Theme.of(context).canvasColor,
      child: Padding(
        padding:
            const EdgeInsets.only(left: 10.0, right: 10, bottom: 30, top: 2),
        child: Row(
          children: [
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
                onPressed: _isTextEmpty
                    ? () => context.push('/chat/voice', extra: {
                          'avatarUrl': widget.receiverAvatarUrl,
                          'avatarId': widget.receiverAvatarId,
                        })
                    : widget.onSend,
                child: Center(
                  child: Icon(
                    _isTextEmpty ? Icons.mic : FeatherIcons.arrowUp,
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
      ),
    );
  }
}
