import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:inzone/services/inzone_database.dart';
import 'package:inzone/theme/app_colors.dart';
import 'package:toasty_box/toast_service.dart';

import '../social_actions_service.dart';

// ---------------------------------------------------------------------------
// Public entry-point — mirrors showGroupChatPopup / showPostComposerPopup
// ---------------------------------------------------------------------------

Future<void> showMessageFriendPopup(
  BuildContext context, {
  required SocialActionsService actions,
  required int? score,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _MessageFriendSheet(actions: actions, score: score),
  );
}

// ---------------------------------------------------------------------------
// Internal contact model
// ---------------------------------------------------------------------------

enum _FilterTab { all, followers, following }

class _Contact {
  const _Contact({
    required this.uid,
    required this.displayName,
    required this.username,
    this.profilePicture,
    this.isFollower = false,
    this.isFollowing = false,
  });

  final String uid;
  final String displayName;
  final String username;
  final String? profilePicture;
  final bool isFollower;
  final bool isFollowing;

  _Contact withFollowing(bool following) => _Contact(
        uid: uid,
        displayName: displayName,
        username: username,
        profilePicture: profilePicture,
        isFollower: isFollower,
        isFollowing: following,
      );

  String get initials {
    final parts = displayName.trim().split(' ');
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    if (displayName.isNotEmpty) return displayName[0].toUpperCase();
    if (username.isNotEmpty) return username[0].toUpperCase();
    return '?';
  }
}

// ---------------------------------------------------------------------------
// Bottom sheet
// ---------------------------------------------------------------------------

class _MessageFriendSheet extends StatefulWidget {
  const _MessageFriendSheet({required this.actions, required this.score});

  final SocialActionsService actions;
  final int? score;

  @override
  State<_MessageFriendSheet> createState() => _MessageFriendSheetState();
}

class _MessageFriendSheetState extends State<_MessageFriendSheet> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final TextEditingController _search = TextEditingController();
  late final TextEditingController _messageController;

  List<_Contact> _contacts = [];
  final Set<String> _selected = {};
  _FilterTab _tab = _FilterTab.all;
  bool _loading = true;
  bool _sending = false;

  String? _currentUid;
  String _currentName = 'Me';

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController(
      text: '${widget.actions.prewrittenMessage(widget.score)}\n'
          '${widget.actions.challengeLink()}',
    );
    _search.addListener(() => setState(() {}));
    _loadContacts();
  }

  @override
  void dispose() {
    _search.dispose();
    _messageController.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Load followers + following from the current user's profile
  // -------------------------------------------------------------------------

  Future<void> _loadContacts() async {
    _currentUid = await InZoneDatabase.getCurrentUserUid();
    if (_currentUid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final profile = await InZoneDatabase.getCurrentUserProfile();
    if (profile != null) {
      _currentName =
          profile['name']?.toString() ??
          profile['Name']?.toString() ??
          _currentName;
    }

    final contacts = <_Contact>[];
    final seen = <String>{};

    // --- Followers ---
    final List<dynamic> followers =
        (profile?['followers'] as List<dynamic>?) ?? [];
    for (final raw in followers) {
      final c = _parse(raw, isFollower: true, isFollowing: false);
      if (c != null && c.uid != _currentUid && !seen.contains(c.uid)) {
        contacts.add(c);
        seen.add(c.uid);
      }
    }

    // --- Following --- (may overlap with followers)
    final List<dynamic> following =
        (profile?['following'] as List<dynamic>?) ?? [];
    for (final raw in following) {
      final uid = _uid(raw);
      if (uid == null || uid.isEmpty || uid == _currentUid) continue;
      if (seen.contains(uid)) {
        final idx = contacts.indexWhere((c) => c.uid == uid);
        if (idx >= 0) contacts[idx] = contacts[idx].withFollowing(true);
      } else {
        final c = _parse(raw, isFollower: false, isFollowing: true);
        if (c != null) {
          contacts.add(c);
          seen.add(c.uid);
        }
      }
    }

    if (mounted) setState(() { _contacts = contacts; _loading = false; });
  }

  String? _uid(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw['id']?.toString();
    if (raw is String) return raw;
    return null;
  }

  _Contact? _parse(dynamic raw, {required bool isFollower, required bool isFollowing}) {
    if (raw is Map<String, dynamic>) {
      final uid = raw['id']?.toString() ?? '';
      if (uid.isEmpty) return null;
      return _Contact(
        uid: uid,
        displayName: raw['name']?.toString() ??
            raw['Name']?.toString() ??
            raw['username']?.toString() ??
            'User',
        username: raw['username']?.toString() ?? uid,
        profilePicture: raw['profilePicture']?.toString(),
        isFollower: isFollower,
        isFollowing: isFollowing,
      );
    }
    if (raw is String && raw.isNotEmpty) {
      return _Contact(
        uid: raw,
        displayName: 'User',
        username: raw,
        isFollower: isFollower,
        isFollowing: isFollowing,
      );
    }
    return null;
  }

  // -------------------------------------------------------------------------
  // Filtered list
  // -------------------------------------------------------------------------

  List<_Contact> get _filtered {
    final q = _search.text.toLowerCase().trim();
    return _contacts.where((c) {
      final tabOk = switch (_tab) {
        _FilterTab.all      => true,
        _FilterTab.followers => c.isFollower,
        _FilterTab.following => c.isFollowing,
      };
      if (!tabOk) return false;
      if (q.isEmpty) return true;
      return c.displayName.toLowerCase().contains(q) ||
          c.username.toLowerCase().contains(q);
    }).toList();
  }

  // -------------------------------------------------------------------------
  // Send — writes directly to Firestore, same schema as HumanChatScreen
  // -------------------------------------------------------------------------

  Future<void> _send() async {
    if (_selected.isEmpty || _sending || _currentUid == null) return;
    setState(() => _sending = true);

    final message = _messageController.text.trim();
    if (message.isEmpty) return;
    final nav = Navigator.of(context);
    final toastCtx = nav.context;
    final cardColor = Theme.of(context).cardColor;

    try {
      // Fetch existing conversations once so we can reuse existing docs
      final snap = await _db
          .collection('conversations')
          .where('participants', arrayContains: _currentUid)
          .get();

      for (final uid in _selected) {
        // Find the contact to get their display name
        _Contact? contact;
        for (final c in _contacts) {
          if (c.uid == uid) { contact = c; break; }
        }
        final recipientName = contact?.displayName ?? 'User';

        // Find existing 1-on-1 conversation
        DocumentReference? convRef;
        for (final doc in snap.docs) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['isGroupChat'] == true) continue;
          final parts = List<dynamic>.from(data['participants'] ?? []);
          if (parts.contains(uid)) { convRef = doc.reference; break; }
        }
        // No existing conversation → create a new one
        convRef ??= _db.collection('conversations').doc();

        // Write message (mirrors HumanChatScreen._sendMessage exactly)
        await convRef.collection('messages').add({
          'text': message,
          'senderId': _currentUid,
          'senderName': _currentName,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
        });

        // Create / update conversation metadata
        await convRef.set({
          'lastMessage': message,
          'lastMessageTime': FieldValue.serverTimestamp(),
          'participants': [_currentUid, uid],
          'participantNames': {
            _currentUid: _currentName,
            uid: recipientName,
          },
          'lastUpdated': FieldValue.serverTimestamp(),
          'isGroupChat': false,
        }, SetOptions(merge: true));
      }

      if (!mounted) return;
      nav.pop();
      final n = _selected.length;
      ToastService.showToast(
        toastCtx,
        backgroundColor: cardColor,
        shadowColor: Colors.transparent,
        leading: const Icon(Icons.send_rounded, color: AppColors.primaryBlue),
        message: n == 1 ? 'Message sent!' : 'Sent to $n friends!',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      ToastService.showToast(
        toastCtx,
        backgroundColor: cardColor,
        shadowColor: Colors.transparent,
        leading: const Icon(Icons.error_outline, color: AppColors.error),
        message: "Couldn't send — try again.",
      );
    }
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final filtered = _filtered;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.72,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
        ),
        child: Column(
          children: [
            // ── Drag handle ──────────────────────────────────────────────
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // ── Header row ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
              child: Row(
                children: [
                  Transform.rotate(
                    angle: -math.pi / 4,
                    child: Icon(Icons.send_rounded, color: theme.primaryColor),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Message a friend',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // ── Search ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: TextField(
                controller: _search,
                decoration: const InputDecoration(
                  hintText: 'Search followers & following…',
                  prefixIcon: Icon(Icons.search_rounded),
                  isDense: true,
                ),
              ),
            ),
            // ── Filter pills ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: _FilterTab.values.map((tab) {
                  final active = _tab == tab;
                  final label = switch (tab) {
                    _FilterTab.all       => 'All',
                    _FilterTab.followers => 'Followers',
                    _FilterTab.following => 'Following',
                  };
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _tab = tab),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 7),
                        decoration: BoxDecoration(
                          gradient: active
                              ? const LinearGradient(
                                  colors: AppColors.blueGradient,
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          border: active
                              ? null
                              : Border.all(
                                  color: theme.dividerColor,
                                  width: 1,
                                ),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: active
                                ? Colors.white
                                : theme.textTheme.bodySmall?.color,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const Divider(height: 1),
            // ── Contact list ─────────────────────────────────────────────
            Expanded(
              child: _loading
                  ? Center(
                      child: CircularProgressIndicator(color: theme.primaryColor),
                    )
                  : filtered.isEmpty
                      ? Center(
                          child: Text(
                            _search.text.isEmpty
                                ? 'No followers or following yet.'
                                : 'No results for "${_search.text}"',
                            style: theme.textTheme.bodySmall,
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: filtered.length,
                          itemBuilder: (_, i) => _contactTile(filtered[i], theme),
                        ),
            ),
            const Divider(height: 1),
            // ── Editable message ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: TextField(
                controller: _messageController,
                minLines: 2,
                maxLines: 4,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.textTheme.bodyMedium?.color,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.primaryBlue.withOpacity(0.07),
                  hintText: 'Write a message…',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: AppColors.primaryBlue.withOpacity(0.4),
                      width: 1,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  isDense: true,
                ),
              ),
            ),
            // ── Send button ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: _selected.isEmpty
                    ? Opacity(
                        opacity: 0.45,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: AppColors.blueGradient,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'Select friends to send',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: AppColors.blueGradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(99),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryBlue.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _sending ? null : _send,
                            borderRadius: BorderRadius.circular(99),
                            child: Center(
                              child: _sending
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.send_rounded,
                                            color: Colors.white, size: 20),
                                        const SizedBox(width: 10),
                                        Text(
                                          _selected.length == 1
                                              ? 'Send to 1 friend'
                                              : 'Send to ${_selected.length} friends',
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contactTile(_Contact contact, ThemeData theme) {
    final selected = _selected.contains(contact.uid);
    final hasPic = contact.profilePicture?.isNotEmpty == true;

    return InkWell(
      onTap: () => setState(() {
        if (selected) {
          _selected.remove(contact.uid);
        } else {
          _selected.add(contact.uid);
        }
      }),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.primaryBlue.withOpacity(0.12),
              backgroundImage: hasPic
                  ? CachedNetworkImageProvider(contact.profilePicture!)
                  : null,
              child: hasPic
                  ? null
                  : Text(
                      contact.initials,
                      style: const TextStyle(
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            // Name + relationship label
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    contact.displayName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _relationLabel(contact),
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
            // Circular toggle
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? AppColors.primaryBlue
                    : Colors.transparent,
                border: Border.all(
                  color: selected
                      ? AppColors.primaryBlue
                      : theme.dividerColor,
                  width: 1.5,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 14)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  String _relationLabel(_Contact c) {
    if (c.isFollower && c.isFollowing) return 'Follower · Following';
    if (c.isFollower) return 'Follower';
    if (c.isFollowing) return 'Following';
    return '';
  }
}
