import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:inzone/theme/app_colors.dart';

import '../game_comments_service.dart';

/// Comments popup for the game social overlay — the app twin of the InZone
/// Games website's comments panel (same Firestore thread, same features:
/// Top/Newest sort, replies, per-comment likes).
///
/// Look & layout mirror the website's MOBILE comments sheet — gradient
/// initial avatars, heart likes, compact "1w" timestamps, count pill and the
/// round sort/close chips in the header — rendered in the app's native theme
/// colors (theme surfaces, AppColors.blueGradient, colorScheme.primary).
///
///  - portrait  → bottom sheet, ~80% tall, 18-radius top corners, slides up
///  - landscape → right-side drawer, full height, slides in from the right
Future<void> showGameCommentsPopup(
  BuildContext context, {
  required GameCommentsService comments,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Comments',
    // Same 50% black backdrop as the website's comments-backdrop.
    barrierColor: Colors.black.withOpacity(0.5),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (_, __, ___) => _GameCommentsPopup(comments: comments),
    transitionBuilder: (context, animation, _, child) {
      final isLandscape =
          MediaQuery.of(context).orientation == Orientation.landscape;
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeIn,
      );
      return SlideTransition(
        // Website: sheet-in (translateY) on mobile portrait, panel-in
        // (translateX) when the panel docks to the right edge.
        position: Tween<Offset>(
          begin: isLandscape ? const Offset(1, 0) : const Offset(0, 1),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      );
    },
  );
}

enum _CommentSort { top, newest }

/// Subtle hairline color for borders and dividers — the app twin of the
/// website's faint `--line` variable. The app themes define their soft grey
/// on `dividerTheme.color` (ThemeData.dividerColor is unset and falls back
/// to a harsh near-black), so read the themed value first.
Color _lineColor(ThemeData theme) =>
    theme.dividerTheme.color ?? theme.dividerColor;

class _GameCommentsPopup extends StatefulWidget {
  const _GameCommentsPopup({required this.comments});

  final GameCommentsService comments;

  @override
  State<_GameCommentsPopup> createState() => _GameCommentsPopupState();
}

class _GameCommentsPopupState extends State<_GameCommentsPopup> {
  final TextEditingController _composer = TextEditingController();

  List<GameComment> _comments = [];
  Set<String> _liked = <String>{};
  final Set<String> _expanded = <String>{};

  bool _loading = true;
  bool _posting = false;
  String? _error;
  _CommentSort _sort = _CommentSort.top;

  /// Comment currently being replied to, or null for a top-level comment.
  GameComment? _replyTo;

  GameCommentIdentity? _identity;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      widget.comments.fetchComments(),
      widget.comments.getLikedCommentIds(),
      widget.comments.resolveIdentity(),
    ]);
    if (!mounted) return;
    setState(() {
      _comments = results[0] as List<GameComment>;
      _liked = results[1] as Set<String>;
      _identity = results[2] as GameCommentIdentity;
      _loading = false;
    });
  }

  // ---------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------

  Future<void> _post() async {
    if (_posting || _composer.text.trim().isEmpty) return;
    setState(() {
      _posting = true;
      _error = null;
    });
    try {
      final created = await widget.comments.addComment(
        _composer.text,
        parentId: _replyTo?.id,
      );
      if (!mounted) return;
      setState(() {
        _comments = [created, ..._comments];
        if (created.parentId != null) _expanded.add(created.parentId!);
        _replyTo = null;
        _posting = false;
      });
      _composer.clear();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _posting = false;
        _error = e is StateError ? e.message : 'Could not post comment.';
      });
    }
  }

  /// Optimistic per-comment like toggle — the shared tally moves on the
  /// server, the "did I like it" flag is remembered on the device. Reverted
  /// if the write fails (same flow as the website).
  Future<void> _toggleLike(GameComment c) async {
    final next = !_liked.contains(c.id);
    setState(() {
      next ? _liked.add(c.id) : _liked.remove(c.id);
      c.likeCount = max(0, c.likeCount + (next ? 1 : -1));
    });
    unawaited(widget.comments.setCommentLiked(c.id, next));
    try {
      await widget.comments.likeComment(c.id, next);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        next ? _liked.remove(c.id) : _liked.add(c.id);
        c.likeCount = max(0, c.likeCount + (next ? -1 : 1));
      });
      unawaited(widget.comments.setCommentLiked(c.id, !next));
    }
  }

  // ---------------------------------------------------------------------
  // Derived data
  // ---------------------------------------------------------------------

  /// Top-level comments in the chosen sort order + replies grouped under
  /// their parent (oldest first), mirroring the website's split.
  (List<GameComment>, Map<String, List<GameComment>>) _split() {
    final tops = <GameComment>[];
    final byParent = <String, List<GameComment>>{};
    for (final c in _comments) {
      final parent = c.parentId;
      if (parent == null) {
        tops.add(c);
      } else {
        (byParent[parent] ??= []).add(c);
      }
    }
    for (final replies in byParent.values) {
      replies.sort((a, b) => (a.createdAt ?? 0).compareTo(b.createdAt ?? 0));
    }
    tops.sort((a, b) {
      if (_sort == _CommentSort.top && b.likeCount != a.likeCount) {
        return b.likeCount - a.likeCount;
      }
      return (b.createdAt ?? 0).compareTo(a.createdAt ?? 0);
    });
    return (tops, byParent);
  }

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final isLandscape = media.orientation == Orientation.landscape;

    final body = Column(
      children: [
        _header(theme),
        Divider(height: 1, color: _lineColor(theme)),
        Expanded(child: _list(theme)),
        _composerBar(theme),
      ],
    );

    if (isLandscape) {
      // Website ≥ tablet width: right-hand drawer, full height.
      return Align(
        alignment: Alignment.centerRight,
        child: SizedBox(
          width: min(420.0, media.size.width * 0.92),
          height: double.infinity,
          child: Material(
            color: theme.scaffoldBackgroundColor,
            child: SafeArea(
              left: false,
              child: Padding(
                padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
                child: body,
              ),
            ),
          ),
        ),
      );
    }

    // Website mobile: bottom sheet at ~80% of the screen height, rounded
    // top corners.
    return Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        width: double.infinity,
        height: media.size.height * 0.8,
        child: Material(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
              child: body,
            ),
          ),
        ),
      ),
    );
  }

  /// Header — the website's comments-head: bold title + count pill on the
  /// left, round sort (Top/Newest) and close chips on the right.
  Widget _header(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
      child: Row(
        children: [
          Text(
            'Comments',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: theme.textTheme.titleMedium?.color,
            ),
          ),
          const SizedBox(width: 12),
          // Count pill (website comments-count chip).
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
            decoration: BoxDecoration(
              color: theme.cardColor,
              border: Border.all(color: _lineColor(theme)),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${_comments.length}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
          ),
          const Spacer(),
          // Top/Newest sort — kept right next to the close button.
          _roundHeaderButton(
            theme,
            child: PopupMenuButton<_CommentSort>(
              tooltip: 'Sort comments',
              initialValue: _sort,
              padding: EdgeInsets.zero,
              onSelected: (value) => setState(() => _sort = value),
              icon: Icon(
                Icons.filter_list,
                size: 19,
                color: theme.iconTheme.color,
              ),
              itemBuilder: (_) => [
                _sortItem(theme, _CommentSort.top, 'Top'),
                _sortItem(theme, _CommentSort.newest, 'Newest'),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _roundHeaderButton(
            theme,
            child: IconButton(
              padding: EdgeInsets.zero,
              iconSize: 19,
              icon: Icon(Icons.close, color: theme.iconTheme.color),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }

  /// Small circular header chip — the website's round icon-btn.
  Widget _roundHeaderButton(ThemeData theme, {required Widget child}) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border.all(color: _lineColor(theme)),
        shape: BoxShape.circle,
      ),
      child: child,
    );
  }

  PopupMenuItem<_CommentSort> _sortItem(
    ThemeData theme,
    _CommentSort value,
    String label,
  ) {
    final active = _sort == value;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
          if (active)
            Icon(Icons.check, size: 18, color: theme.colorScheme.primary),
        ],
      ),
    );
  }

  Widget _list(ThemeData theme) {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: theme.colorScheme.primary),
      );
    }
    final (tops, byParent) = _split();
    if (tops.isEmpty) {
      return Center(
        child: Text(
          'No comments yet. Be the first!',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.textTheme.bodySmall?.color),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      itemCount: tops.length,
      itemBuilder: (_, i) => _commentTile(
        theme,
        tops[i],
        replies: byParent[tops[i].id] ?? const [],
      ),
    );
  }

  /// One comment row — the website's comment block: gradient initial avatar,
  /// author + compact time, text, heart + Reply actions, replies behind a
  /// soft left rule.
  Widget _commentTile(
    ThemeData theme,
    GameComment c, {
    List<GameComment> replies = const [],
    bool isReply = false,
  }) {
    final liked = _liked.contains(c.id);
    final expanded = _expanded.contains(c.id);
    final mutedColor = theme.textTheme.bodySmall?.color;

    return Padding(
      padding: EdgeInsets.only(bottom: isReply ? 18 : 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _avatar(c, small: isReply),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Author + compact "1w" timestamp on one line.
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        c.authorName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: isReply ? 14 : 15,
                          fontWeight: FontWeight.w700,
                          color: theme.textTheme.titleMedium?.color,
                        ),
                      ),
                    ),
                    if (c.createdAt != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        _timeAgo(c.createdAt!),
                        style: TextStyle(
                          fontSize: 12,
                          color: mutedColor?.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  c.text,
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.5,
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                ),
                // Actions: heart like (+ count when > 0) and a plain Reply
                // text button, like the website.
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () => _toggleLike(c),
                        borderRadius: BorderRadius.circular(8),
                        child: Row(
                          children: [
                            Icon(
                              liked
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 18,
                              color: liked ? AppColors.error : mutedColor,
                            ),
                            if (c.likeCount > 0) ...[
                              const SizedBox(width: 6),
                              Text(
                                '${c.likeCount}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: mutedColor,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 18),
                      if (!isReply)
                        InkWell(
                          onTap: () => setState(() => _replyTo = c),
                          borderRadius: BorderRadius.circular(8),
                          child: Text(
                            'Reply',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: mutedColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // "⌄ 1 reply" / "⌃ Hide replies" toggle, primary-tinted like
                // the website's blue comment-replies-toggle.
                if (replies.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: InkWell(
                      onTap: () => setState(() {
                        expanded
                            ? _expanded.remove(c.id)
                            : _expanded.add(c.id);
                      }),
                      borderRadius: BorderRadius.circular(8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            expanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            size: 17,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            expanded
                                ? 'Hide replies'
                                : '${replies.length} ${replies.length == 1 ? 'reply' : 'replies'}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Replies column behind a soft left rule.
                if (replies.isNotEmpty && expanded)
                  Container(
                    margin: const EdgeInsets.only(top: 14),
                    padding: const EdgeInsets.only(left: 16),
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(color: _lineColor(theme), width: 2),
                      ),
                    ),
                    child: Column(
                      children: replies
                          .map((r) => _commentTile(theme, r, isReply: true))
                          .toList(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Round gradient avatar with the author's initial — the website's
  /// comment-avatar, in the app's blue gradient.
  Widget _avatar(GameComment c, {required bool small}) {
    final size = small ? 32.0 : 42.0;
    final initial =
        c.authorName.isEmpty ? '?' : c.authorName[0].toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: AppColors.blueGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: small ? 12 : 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  /// Compose bar — "Commenting as <name> [GUEST]" line, pill input and the
  /// round send button.
  Widget _composerBar(ThemeData theme) {
    final replyTo = _replyTo;
    return Container(
      color: theme.cardColor,
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Reply banner (website reply-banner) — soft rounded chip with a
          // cancel X.
          if (replyTo != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                border: Border.all(color: _lineColor(theme)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: 'Replying to ',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: theme.textTheme.bodySmall?.color,
                        ),
                        children: [
                          TextSpan(
                            text: replyTo.authorName,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: theme.textTheme.titleMedium?.color,
                            ),
                          ),
                        ],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: () => setState(() => _replyTo = null),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        Icons.close,
                        size: 14,
                        color: theme.iconTheme.color,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (_identity != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Flexible(
                    child: Text.rich(
                      TextSpan(
                        text: 'Commenting as ',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: theme.textTheme.bodySmall?.color,
                        ),
                        children: [
                          TextSpan(
                            text: _identity!.username,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: theme.textTheme.titleMedium?.color,
                            ),
                          ),
                        ],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Website guest-tag pill.
                  if (_identity!.anonymous) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.scaffoldBackgroundColor,
                        border: Border.all(color: _lineColor(theme)),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'GUEST',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                          color: theme.textTheme.bodySmall?.color,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                _error!,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Pill-shaped input (website compose-input).
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(minHeight: 46),
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    border: Border.all(color: _lineColor(theme)),
                    borderRadius: BorderRadius.circular(23),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: TextField(
                    controller: _composer,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: GameCommentsService.maxCommentLen,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _post(),
                    style: theme.textTheme.bodyMedium,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      counterText: '',
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 13),
                      hintText: replyTo != null
                          ? 'Reply to ${replyTo.authorName}…'
                          : 'Add a comment…',
                      hintStyle: TextStyle(color: theme.hintColor),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Round send button, app primary color (kept as-is).
              SizedBox(
                width: 46,
                height: 46,
                child: Material(
                  color: theme.colorScheme.primary,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _posting ? null : _post,
                    child: Center(
                      child: _posting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 19,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Compact website-style timestamps: now, 5m, 3h, 2d, 1w, 1y.
String _timeAgo(int epochMillis) {
  final diff = DateTime.now()
      .difference(DateTime.fromMillisecondsSinceEpoch(epochMillis));
  if (diff.inSeconds < 60) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  if (diff.inDays < 365) return '${(diff.inDays / 7).floor()}w';
  return '${(diff.inDays / 365).floor()}y';
}
