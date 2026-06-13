import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:inzone/data/group_chat_data.dart';
import 'package:inzone/theme/light_theme.dart'; // ChatTheme extension

import '../social_actions_service.dart';

/// Bottom-sheet popup for the "Open chat" action: live group chat from
/// `GroupChatService` plus a text field prefilled with the prewritten
/// message. Bubble colors come from the app's ChatTheme extension so it
/// matches the real chat screen in both light and dark themes.
Future<void> showGroupChatPopup(
  BuildContext context, {
  required SocialActionsService actions,
  required String prefilledMessage,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _GroupChatSheet(
      actions: actions,
      prefilledMessage: prefilledMessage,
    ),
  );
}

class _GroupChatSheet extends StatefulWidget {
  const _GroupChatSheet({
    required this.actions,
    required this.prefilledMessage,
  });

  final SocialActionsService actions;
  final String prefilledMessage;

  @override
  State<_GroupChatSheet> createState() => _GroupChatSheetState();
}

class _GroupChatSheetState extends State<_GroupChatSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.prefilledMessage);
  bool _sending = false;

  String? get _myUid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await widget.actions.sendChatMessage(_controller.text);
      if (mounted) {
        // Keep the sheet open so the user sees their message land in the
        // stream; just clear the input.
        _controller.clear();
        setState(() => _sending = false);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't send — try again.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.55,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
              child: Row(
                children: [
                  Icon(Icons.groups_rounded, color: theme.primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StreamBuilder<GroupChatData>(
                      stream: widget.actions.groupChatStream(),
                      builder: (context, snap) => Text(
                        snap.data?.name.isNotEmpty == true
                            ? snap.data!.name
                            : 'Group chat',
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: StreamBuilder<GroupChatData>(
                stream: widget.actions.groupChatStream(),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return Center(
                      child:
                          CircularProgressIndicator(color: theme.primaryColor),
                    );
                  }
                  final messages = snap.data!.messages;
                  if (messages.isEmpty) {
                    return Center(
                      child: Text('No messages yet — say hi!',
                          style: theme.textTheme.bodySmall),
                    );
                  }
                  // Newest at the bottom; show the most recent ~30.
                  final recent = messages.length > 30
                      ? messages.sublist(messages.length - 30)
                      : messages;
                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    itemCount: recent.length,
                    itemBuilder: (_, i) => _MessageBubble(
                      message: recent[recent.length - 1 - i],
                      isMine:
                          recent[recent.length - 1 - i].sender.uid == _myUid,
                    ),
                  );
                },
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Message the group…',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Material(
                    color: theme.primaryColor,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _sending ? null : _send,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_rounded,
                                color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMine});

  final ChatMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bubbleColor =
        isMine ? theme.myChatBubbleColor : theme.otherChatBubbleColor;
    final textColor =
        isMine ? theme.myChatTextColor : theme.otherChatTextColor;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment:
            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMine)
            Text(message.sender.name, style: theme.textTheme.labelSmall),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(message.content,
                style: TextStyle(color: textColor, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
