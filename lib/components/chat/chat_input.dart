import 'package:flutter/material.dart';

class ChatInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final String hintText;
  final ScrollController? scrollController;

  const ChatInput({
    super.key,
    required this.controller,
    required this.onSend,
    this.hintText = 'Send a message',
    this.scrollController,
  });

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
                controller: scrollController,
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 100),
                  child: TextFormField(
                    scrollController: scrollController,
                    cursorColor: Theme.of(context).primaryColor,
                    controller: controller,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    onFieldSubmitted: (_) => onSend(),
                    textInputAction: TextInputAction.send,
                    onEditingComplete: onSend,
                    onTap: () {
                      controller.addListener(() {
                        if (controller.text.endsWith('\n')) {
                          controller.text = controller.text
                              .substring(0, controller.text.length - 1);
                          onSend();
                        }
                      });
                    },
                    decoration: InputDecoration(
                      suffixIconColor: Theme.of(context).iconTheme.color,
                      contentPadding:
                          const EdgeInsets.only(top: 10, left: 15, right: 10),
                      border: InputBorder.none,
                      hintText: hintText,
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
              onPressed: onSend,
              child: const Center(
                child: Icon(
                  Icons.send_rounded,
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
