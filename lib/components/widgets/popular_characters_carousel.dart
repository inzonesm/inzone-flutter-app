import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inzone/components/profile/avatar_card.dart';
import 'package:inzone/data/inzone_avatar.dart';
import 'package:inzone/router/routes.dart';
import 'package:inzone/screen/chat/all_chats_screen.dart';

class PopularCharactersCarousel extends StatelessWidget {
  final List<InZoneAvatar> avatars;

  const PopularCharactersCarousel({
    super.key,
    required this.avatars,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 550,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              "Popular Characters",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: avatars.length,
              itemBuilder: (context, index) {
                final avatar = avatars[index];
                return Padding(
                  padding: EdgeInsets.only(
                    left: index == 0 ? 16 : 5,
                    right: index == avatars.length - 1 ? 16 : 5,
                  ),
                  child: GestureDetector(
                    onTap: () {
                      context.pushNamed('chat',
                          extra: ChatUser(
                            name: avatar.name,
                            email: avatar.id,
                            chatId: null,
                            isHuman: false,
                            profilePictureURL: avatar.profilePicture,
                          ));
                    },
                    child: AvatarCard(avatar: avatars[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
