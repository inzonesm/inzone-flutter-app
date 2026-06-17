import 'dart:async';

import 'package:flutter/material.dart';
import 'package:inzone/theme/app_colors.dart';

import 'popups/group_chat_popup.dart';
import 'popups/message_friend_popup.dart';
import 'popups/post_composer_popup.dart';
import 'social_actions_service.dart';
import 'social_bridge.dart';

/// Floating social button + expandable menu, drawn on top of the game
/// webview in `_CommunityGamePage`. Works for every `html_games` upload
/// with zero game-side integration — the alternative to the in-game
/// `send-challenge` / `open-chat` SDK endpoints.
///
/// Styling follows the app's existing game screen and Game Over dialog:
/// blue-gradient FAB (AppColors.blueGradient), white 15-radius menu card
/// (like the feed post cards), primaryBlue icons.
///
/// The button starts top-right at the same vertical level as the back
/// button in `_GameTopOverlay`, and is draggable: on release it snaps to
/// the nearest horizontal edge; the menu opens toward available space.
///
/// Flows:
///  - Send challenge        → native OS share sheet (SharePlus)
///  - Open chat             → group chat bottom sheet with prefilled message
///  - Share score to InZone → Game Over-styled composer → createRepost
class GameSocialOverlay extends StatefulWidget {
  const GameSocialOverlay({
    super.key,
    required this.bridge,
    required this.actions,
    this.edgeMargin = 12,
    this.initialTopOffset = 6,
    this.initialPosition,
    this.onPositionChanged,
  });

  final SocialBridge bridge;
  final SocialActionsService actions;

  /// Gap kept between the button and the screen edges.
  final double edgeMargin;

  /// Initial distance below the safe area. 6 puts the 44px button at the
  /// same vertical level as `_GameTopOverlay`'s 48px back IconButton.
  final double initialTopOffset;

  /// Restore a previously saved position (overrides [initialTopOffset]).
  final Offset? initialPosition;

  /// Called after a drag snaps; persist per game (e.g. SharedPreferences
  /// keyed by game id) to remember the spot across sessions.
  final ValueChanged<Offset>? onPositionChanged;

  @override
  State<GameSocialOverlay> createState() => _GameSocialOverlayState();
}

class _GameSocialOverlayState extends State<GameSocialOverlay>
    with SingleTickerProviderStateMixin {
  static const double _buttonSize = 44;
  static const double _menuWidth = 224;
  static const double _menuGap = 8;

  bool _expanded = false;
  bool _idle = false;
  bool _dragging = false;

  /// Top-left of the button in overlay coordinates; null until first layout.
  Offset? _position;

  Timer? _idleTimer;

  late final AnimationController _menuController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );
  late final Animation<double> _menuAnimation = CurvedAnimation(
    parent: _menuController,
    curve: Curves.easeOutBack,
    reverseCurve: Curves.easeIn,
  );

  @override
  void initState() {
    super.initState();
    _position = widget.initialPosition;
    _restartIdleTimer();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _menuController.dispose();
    super.dispose();
  }

  void _restartIdleTimer() {
    _idleTimer?.cancel();
    if (_idle) setState(() => _idle = false);
    _idleTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && !_expanded && !_dragging) setState(() => _idle = true);
    });
  }

  void _toggle() {
    _restartIdleTimer();
    setState(() => _expanded = !_expanded);
    _expanded ? _menuController.forward() : _menuController.reverse();
  }

  void _close() {
    if (!_expanded) return;
    setState(() => _expanded = false);
    _menuController.reverse();
    _restartIdleTimer();
  }

  int? get _score => widget.bridge.latestScore;

  // -------------------------------------------------------------------
  // Drag & snap
  // -------------------------------------------------------------------

  Offset _clampToBounds(Offset p, Size size, EdgeInsets safe) {
    final maxX = size.width - _buttonSize - widget.edgeMargin;
    final maxY = size.height - safe.bottom - _buttonSize - widget.edgeMargin;
    return Offset(
      p.dx.clamp(widget.edgeMargin, maxX),
      p.dy.clamp(safe.top + widget.edgeMargin, maxY),
    );
  }

  void _onPanStart(DragStartDetails _) {
    _idleTimer?.cancel();
    setState(() {
      _dragging = true;
      _idle = false;
    });
    _close();
  }

  void _onPanUpdate(DragUpdateDetails details, Size size, EdgeInsets safe) {
    setState(() {
      _position = _clampToBounds(_position! + details.delta, size, safe);
    });
  }

  void _onPanEnd(Size size, EdgeInsets safe) {
    final p = _clampToBounds(_position!, size, safe);
    final snapLeft = p.dx + _buttonSize / 2 < size.width / 2;
    final snappedX = snapLeft
        ? widget.edgeMargin
        : size.width - _buttonSize - widget.edgeMargin;
    setState(() {
      _dragging = false;
      _position = Offset(snappedX, p.dy);
    });
    widget.onPositionChanged?.call(_position!);
    _restartIdleTimer();
  }

  // -------------------------------------------------------------------
  // The three flows
  // -------------------------------------------------------------------

  Future<void> _onSendChallenge() async {
    _close();
    // Opens the device's native OS share sheet.
    await widget.actions.sendChallenge(_score);
  }

  Future<void> _onOpenChat() async {
    _close();
    await showGroupChatPopup(
      context,
      actions: widget.actions,
      prefilledMessage: widget.actions.prewrittenMessage(_score),
    );
  }

  Future<void> _onMessageFriend() async {
    _close();
    await showMessageFriendPopup(
      context,
      actions: widget.actions,
      score: _score,
    );
  }

  Future<void> _onShareToFeed() async {
    _close();
    await showPostComposerPopup(
      context,
      actions: widget.actions,
      score: _score,
    );
  }

  // -------------------------------------------------------------------
  // UI
  // -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.of(context).padding;

    return LayoutBuilder(builder: (context, constraints) {
      final size = constraints.biggest;

      // Default: top-right, level with the back button on the top-left.
      _position ??= Offset(
        size.width - _buttonSize - widget.edgeMargin,
        safe.top + widget.initialTopOffset,
      );
      final pos = _clampToBounds(_position!, size, safe);

      final dockedLeft = pos.dx + _buttonSize / 2 < size.width / 2;
      final opensDown = pos.dy + _buttonSize / 2 < size.height / 2;

      return Stack(
        children: [
          // Scrim — same 30% black the root app uses for its expanded
          // overlay. Only present while the menu is open, so the game
          // receives all touches otherwise.
          if (_expanded)
            Positioned.fill(
              child: GestureDetector(
                onTap: _close,
                child: Container(color: Colors.black.withOpacity(0.3)),
              ),
            ),
          Positioned(
            left: dockedLeft ? pos.dx : null,
            right: dockedLeft ? null : size.width - pos.dx - _buttonSize,
            top: opensDown ? pos.dy + _buttonSize + _menuGap : null,
            bottom: opensDown ? null : size.height - pos.dy + _menuGap,
            child: SizeTransition(
              sizeFactor: _menuAnimation,
              axisAlignment: opensDown ? -1 : 1,
              child: FadeTransition(
                opacity: _menuAnimation,
                child: _menu(),
              ),
            ),
          ),
          // Draggable floating button. Zero-duration while dragging so it
          // tracks the finger; animated when snapping to an edge.
          AnimatedPositioned(
            duration: _dragging
                ? Duration.zero
                : const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            left: pos.dx,
            top: pos.dy,
            child: GestureDetector(
              onPanStart: _onPanStart,
              onPanUpdate: (d) => _onPanUpdate(d, size, safe),
              onPanEnd: (_) => _onPanEnd(size, safe),
              child: _floatingButton(),
            ),
          ),
        ],
      );
    });
  }

  Widget _floatingButton() {
    return AnimatedOpacity(
      opacity: _idle ? 0.4 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        width: _buttonSize,
        height: _buttonSize,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: AppColors.blueGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryBlue.withOpacity(_dragging ? 0.5 : 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _toggle,
            child: Icon(
              _expanded ? Icons.close_rounded : Icons.ios_share,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }

  Widget _menu() {
    final theme = Theme.of(context);
    return Container(
      width: _menuWidth,
      decoration: BoxDecoration(
        color: theme.cardColor,
        // 15-radius + soft shadow — same treatment as the feed post cards.
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _menuItem(
            icon: Icons.sports_esports,
            label: 'Send challenge',
            onTap: _onSendChallenge,
          ),
          const Divider(indent: 48),
          _menuItem(
            icon: Icons.chat_bubble_rounded,
            label: 'Open chat',
            onTap: _onOpenChat,
          ),
          const Divider(indent: 48),
          _menuItem(
            icon: Icons.people_rounded,
            label: 'Message a friend',
            onTap: _onMessageFriend,
          ),
          const Divider(indent: 48),
          _menuItem(
            icon: Icons.campaign_rounded,
            label: 'Share score to InZone',
            onTap: _onShareToFeed,
          ),
        ],
      ),
    );
  }

  Widget _menuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            const SizedBox(width: 14),
            Icon(icon, size: 20, color: theme.primaryColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.textTheme.bodyMedium?.color,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}
