import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:inzone/components/chat/message_bubble.dart';

class SampleChatPage extends StatefulWidget {
  final String category;
  const SampleChatPage({super.key, required this.category});

  @override
  _SampleChatPageState createState() => _SampleChatPageState();
}

class _SampleMessage {
  final String sender;
  final String message;
  final bool isMe;

  const _SampleMessage(
      {required this.sender, required this.message, this.isMe = false});
}

class _SampleChatPageState extends State<SampleChatPage>
    with TickerProviderStateMixin {
  AnimationController? _refreshFriendsController;
  String? formattedTime;
  final String _code = "00000000";
  String? _expires;
  String? _url;

  List<_SampleMessage> _getCategoryChatData() {
    switch (widget.category) {
      case 'social':
        return const [
          _SampleMessage(
              sender: 'Charli (AI)',
              message:
                  'I practiced with CoppaBeats’ hottest track on repeat until my legs ached. Then I just let the music flow.'),
          _SampleMessage(
              sender: 'User2',
              message:
                  'Noah, what’s your secret for landing collabs so fast? 😎'),
          _SampleMessage(
              sender: 'Noah Beck (AI)',
              message:
                  'I DM people with ideas, not just a ‘hey.’ Show genuine interest and bring something fresh to the table.'),
          _SampleMessage(
              sender: 'User3',
              message:
                  'Okay, I’m in - challenge accepted. Who’s up for a side-step contest right now?',
              isMe: true),
        ];
      case 'geek':
        return const [
          _SampleMessage(
              sender: 'Spider-Man (AI)',
              message:
                  'My Spider-Sense was buzzing so hard I swung into a Stark tech portal before he knew it.'),
          _SampleMessage(
              sender: 'User2',
              message:
                  'Wanda, how do you manage chaos magic and still remember to take a coffee break? ☕'),
          _SampleMessage(
              sender: 'Wanda Maximoff (AI)',
              message:
                  'I schedule it in between reality-patch calls. Even reality-benders need caffeine.'),
          _SampleMessage(
              sender: 'User3',
              message:
                  'I want in on your next multiverse meetup - count me in for the beta test group!',
              isMe: true),
        ];
      case 'icons':
        return const [
          _SampleMessage(
              sender: 'LeBron James (AI)',
              message:
                  'I felt the arena buzzing and thought, ‘Why not?’ I said to myself, ‘This is my moment.’'),
          _SampleMessage(
              sender: 'User2',
              message:
                  'Jordan, if you defended LeBron in your prime, how would you adjust your strategy? 🤔'),
          _SampleMessage(
              sender: 'Michael Jordan (AI)',
              message:
                  'Keep him off the three line and force him into mid-range. But I’d watch out for that step-back.'),
          _SampleMessage(
              sender: 'User3',
              message: 'I’m taking notes - now let’s debate next season’s MVP!',
              isMe: true),
        ];
      default: // other
        return const [
          _SampleMessage(
              sender: 'Mario (AI)',
              message:
                  'A turbo star so I shine like the sun and leave trails of rainbow blocks.'),
          _SampleMessage(
              sender: 'User2',
              message:
                  'Sonic, would you swap your spin dash for Mario’s fire flower? 🌸'),
          _SampleMessage(
              sender: 'Sonic (AI)',
              message:
                  'Only if it shoots rings instead of flames - that’d be hype.'),
          _SampleMessage(
              sender: 'User3',
              message:
                  'I’m placing my bet on the rainbow blocks - let the race begin!',
              isMe: true),
        ];
    }
  }

  List<String> _getCategoryTitle() {
    switch (widget.category) {
      case 'social':
        return [
          'Talk Like a Fan',
          'Use fun, casual language emojis, and challenge vibes welcome',
          "540",
        ];
      case 'geek':
        return [
          'Power Talk',
          'Ask bold. Think powers. Go all in',
          "510",
        ];
      case 'icons':
        return [
          '“Keep It Real”',
          'Talk like a real convo',
          "510",
        ];
      default:
        return [
          'Simple Talk',
          'Just ask naturally like texting a smart friend',
          "480",
        ];
    }
  }

  @override
  void initState() {
    _refreshFriendsController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    super.initState();
  }

  @override
  void dispose() {
    _refreshFriendsController!.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatData = _getCategoryChatData();
    final title = _getCategoryTitle();

    print(_expires);
    return Scaffold(
      backgroundColor: Colors.grey.withOpacity(0.5),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 15),
              height: double.parse(title[2]),
              width: MediaQuery.of(context).size.width,
              decoration: BoxDecoration(
                color: Theme.of(context).canvasColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    title[0],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.titleLarge?.color,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text(
                      title[1],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 10),
                      itemCount: chatData.length,
                      itemBuilder: (context, index) {
                        final message = chatData[index];
                        return MessageBubble(
                          isMe: message.isMe,
                          message: message.message,
                          senderName: message.isMe ? null : message.sender,
                          senderAvatar: message.isMe
                              ? null
                              : CircleAvatar(
                                  child: Text(message.sender[0]),
                                ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => Navigator.pop(context, _code),
              child: CircleAvatar(
                radius: 25, // Increased radius for a larger avatar
                backgroundColor: Theme.of(context).cardColor,
                child: Icon(
                  FeatherIcons.x,
                  size: 25, // Increased size for the icon
                  color: Theme.of(context).iconTheme.color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
