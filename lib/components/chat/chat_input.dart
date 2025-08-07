import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ChatInput extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final String hintText;
  final ScrollController? scrollController;
  final String receiverAvatarUrl;

  const ChatInput({
    super.key,
    required this.controller,
    required this.onSend,
    this.hintText = 'Send a message',
    this.scrollController,
    this.receiverAvatarUrl = "",
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
                    cursorColor: Theme.of(context).primaryColor,
                    controller: widget.controller,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    onFieldSubmitted:
                        _isTextEmpty ? null : (_) => widget.onSend(),
                    textInputAction: TextInputAction.send,
                    decoration: InputDecoration(
                      suffixIconColor: Theme.of(context).iconTheme.color,
                      contentPadding:
                          const EdgeInsets.only(top: 10, left: 15, right: 10),
                      border: InputBorder.none,
                      hintText: widget.hintText,
                      filled: true,
                      fillColor: Theme.of(context)
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
                        borderSide: BorderSide(
                          color:
                              Theme.of(context).primaryColor.withOpacity(0.3),
                        ),
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            MaterialButton(
              minWidth: 43,
              height: 43,
              color: Theme.of(context).colorScheme.primary,
              shape: const CircleBorder(),
              onPressed: _isTextEmpty
                  ? () => context.push('/chat/voice',
                      extra: {'avatarUrl': widget.receiverAvatarUrl})
                  : widget.onSend,
              child: Center(
                child: Icon(
                  _isTextEmpty ? Icons.mic : Icons.send_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
