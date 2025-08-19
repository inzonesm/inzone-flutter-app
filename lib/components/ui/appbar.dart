import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:inzone/services/monetization_service.dart';
import 'package:popover/popover.dart';
import 'package:toasty_box/toast_service.dart';

class CustomAppBar extends StatefulWidget implements PreferredSizeWidget {
  final String? greeting;
  final String? title;
  final String? subtitle;
  final String? userPoints;
  final String? profileImageUrl;
  final VoidCallback? onSearchTap;
  final VoidCallback? onProfileTap;
  final VoidCallback? onPointsTap;
  final VoidCallback? onNotificationTap;
  final bool isHome;
  final bool isGroup;
  final bool isChat;
  final bool isImage;
  final bool isSettings;
  final bool isDebug;
  final bool isCustom;
  final String userName;

  const CustomAppBar({
    super.key,
    this.greeting,
    this.title,
    this.subtitle,
    this.userPoints,
    this.profileImageUrl,
    this.onSearchTap,
    this.onProfileTap,
    this.onPointsTap,
    this.onNotificationTap,
    this.isHome = false,
    this.isGroup = false,
    this.isChat = false,
    this.isImage = true,
    this.isSettings = false,
    this.isDebug = false,
    this.isCustom = false,
    this.userName = "Loading",
  });

  @override
  State<CustomAppBar> createState() => _CustomAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(70);
}

class _CustomAppBarState extends State<CustomAppBar> {
  final MonetizationService _monetizationService = MonetizationService();
  String _userBalance = '0';

  @override
  void initState() {
    super.initState();
    _loadUserBalance();
  }

  Future<void> _loadUserBalance() async {
    try {
      final response = await _monetizationService.getBalance();

      if (response['success'] == true) {
        final balance = response['data']['balance'];

        if (mounted) {
          setState(() {
            _userBalance = balance.toString();
          });
        }
      } else {}
    } catch (e) {
      debugPrint('CustomAppBar: Error loading balance: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use either the passed userPoints or the dynamically loaded balance
    final displayBalance = widget.userPoints ?? _userBalance;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).canvasColor,
        // color: Colors.red,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: widget.isSettings ? 12 : 24.0, vertical: 12.0),
        child: widget.isHome
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (widget.isSettings)
                    Padding(
                      padding: const EdgeInsets.only(left: 3.0),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.of(context).pop();
                        },
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor:
                              Theme.of(context).brightness == Brightness.dark
                                  ? Colors.grey.shade800
                                  : Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withOpacity(0.2),
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Center(
                              child: Icon(
                                Icons.arrow_back_ios,
                                size: 18,
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.grey.shade400
                                    : Colors.blue.shade600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  // IconButton(
                  //   onPressed: () {
                  //     Navigator.of(context).pop();
                  //   },
                  //   icon: const Icon(CupertinoIcons.back),
                  // ),

                  if (widget.isHome &&
                      !widget.isGroup &&
                      !widget.isChat &&
                      !widget.isSettings)
                    GestureDetector(
                      onTap: () {
                        showPopover(
                          context: context,
                          bodyBuilder: (context) => const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Center(
                              child: Text(
                                  'Enjoy a personalized mix of videos, photos, and text content selected just for you. Tap AI icons in the carousel or story strip to spark a new real-time chat with your favorite personas.'),
                            ),
                          ),
                          onPop: () => print('Popover was popped!'),
                          direction: PopoverDirection.bottom,
                          arrowDyOffset: -20,
                          arrowDxOffset: -73,
                          width: 270,
                          height: 130,
                          arrowHeight: 15,
                          arrowWidth: 30,
                          backgroundColor: Theme.of(context).cardColor,
                        );
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Text(
                              "InZone",
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Icon(
                            FeatherIcons.info,
                            color: Theme.of(context).iconTheme.color,
                            size: 15,
                          ),
                        ],
                      ),
                    ),

                  if (widget.isHome &&
                      widget.isGroup &&
                      !widget.isChat &&
                      !widget.isSettings)
                    GestureDetector(
                      onTap: () {
                        showPopover(
                          context: context,
                          bodyBuilder: (context) => const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Center(
                              child: Text(
                                  'Dive into live rooms on sports, movies, reality TV, music, fantasy, and more. Debate live games with pro athletes, dissect tonight’s episode with the stars, or throw down your hottest “who’s the GOAT” take.'),
                            ),
                          ),
                          onPop: () => print('Popover was popped!'),
                          direction: PopoverDirection.bottom,
                          arrowDyOffset: -20,
                          arrowDxOffset: -70,
                          width: 270,
                          height: 133,
                          arrowHeight: 15,
                          arrowWidth: 30,
                          backgroundColor: Theme.of(context).cardColor,
                        );
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Text(
                              "Groups",
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Icon(
                            FeatherIcons.info,
                            color: Theme.of(context).iconTheme.color,
                            size: 15,
                          ),
                        ],
                      ),
                    ),
                  if (widget.isSettings) const SizedBox(width: 10),
                  Padding(
                    padding: EdgeInsets.only(top: widget.isSettings ? 0 : 5),
                    child: Text(
                      widget.isCustom
                          ? widget.title!
                          : widget.isChat
                              ? 'Chats'
                              : widget.isSettings
                                  ? widget.title ?? 'InZone'
                                  : '',
                      style: widget.isSettings
                          ? Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                              )
                          : Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  const Spacer(),
                  if (widget.isHome &&
                      !widget.isGroup &&
                      !widget.isChat &&
                      !widget.isSettings)
                    GestureDetector(
                      onTap: widget.onSearchTap,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).cardColor,
                        ),
                        child: Icon(
                          Icons.search,
                          color: Theme.of(context).iconTheme.color,
                          size: 28,
                        ),
                      ),
                    ),
                  if (!widget.isDebug) const SizedBox(width: 8),
                  if (!widget.isDebug)
                    if (widget.isHome &&
                        !widget.isGroup &&
                        !widget.isChat &&
                        !widget.isSettings)
                      GestureDetector(
                        onTap: widget.onNotificationTap,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Theme.of(context).cardColor,
                          ),
                          child: Icon(
                            Icons.notifications,
                            color: Theme.of(context).iconTheme.color,
                            size: 28,
                          ),
                        ),
                      ),

                  if (widget.isGroup && widget.onSearchTap != null)
                    GestureDetector(
                      onTap: widget.onSearchTap,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).cardColor,
                        ),
                        child: Icon(
                          Icons.add,
                          color: Theme.of(context).iconTheme.color,
                          size: 24,
                        ),
                      ),
                    ),
                  if (widget.isGroup && widget.onSearchTap != null)
                    const SizedBox(width: 12),
                  // points display
                  if (widget.isGroup)
                    GestureDetector(
                      onTap: widget.onPointsTap,
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          color: Theme.of(context).cardColor,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                              child: const Icon(
                                Icons.local_police,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              displayBalance, // Use the dynamic balance
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (widget.isChat && widget.subtitle != null)
                    GestureDetector(
                      onTap: widget.onSearchTap,
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          color: Theme.of(context).cardColor,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                              child: const Icon(
                                CupertinoIcons.chat_bubble_2,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.subtitle!,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              )
            : widget.isGroup
                ? Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          CupertinoIcons.back,
                          color: Theme.of(context).iconTheme.color,
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                      widget.isImage
                          ? GestureDetector(
                              onTap: widget.onProfileTap,
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                ),
                                child: widget.profileImageUrl != null
                                    ? ClipOval(
                                        child: Image.network(
                                          widget.profileImageUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                            return const Icon(
                                              Icons.account_circle,
                                              size: 48,
                                            );
                                          },
                                        ),
                                      )
                                    : const Icon(
                                        Icons.account_circle,
                                        size: 48,
                                      ),
                              ),
                            )
                          : const SizedBox(),
                      widget.isImage
                          ? const SizedBox(width: 12)
                          : const SizedBox(),
                      Text(
                        widget.title ?? 'Guest',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  )
                : const SizedBox(),
      ),
    );
  }
}

class CustomAppBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  CustomAppBarDelegate({required this.child, this.height = 70});

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox(
      height: height,
      child: child,
    );
  }

  @override
  double get maxExtent => height;

  @override
  double get minExtent => height;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return false;
  }
}
