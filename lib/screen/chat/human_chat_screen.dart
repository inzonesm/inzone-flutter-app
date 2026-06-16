import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:inzone/auth/auth_work.dart';
import 'package:inzone/components/chat/chat_app_bar.dart';
import 'package:inzone/components/chat/chat_input.dart';
import 'package:inzone/components/chat/date_header.dart';
import 'package:inzone/components/chat/message_bubble.dart';
import 'package:inzone/services/inzone_database.dart';
import 'package:inzone/services/notification_event_service.dart';
import 'package:inzone/services/ai_engagement_service.dart';
import 'package:inzone/router/routes.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:toasty_box/toast_service.dart';

class HumanChatScreen extends StatefulWidget {
  final String conversationId; // Unique ID for this conversation
  final String otherUserName; // Name of the person we're chatting with
  final String otherUserId; // ID of the person we're chatting with

  const HumanChatScreen({
    super.key,
    required this.conversationId,
    required this.otherUserName,
    required this.otherUserId,
  });

  @override
  State<HumanChatScreen> createState() => _HumanChatScreenState();
}

class _HumanChatScreenState extends State<HumanChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? currentUserId;
  String currentUserName = "Me";
  bool isLoading = true;
  String _otherUserProfileImageUrl = '';
  bool _isOtherUserHuman = false;
  String? _otherUserResolvedUid;
  File? _pendingImage;
  File? _pendingVideo;
  bool _isSendingMessage = false;
  bool _didInitialAutoScroll = false;
  int _lastRenderedMessageCount = 0;
  String _lastSnapshotSignature = '';
  final ValueNotifier<Map<String, bool>> _timestampVisibilityOverrides =
      ValueNotifier<Map<String, bool>>({});
  final Map<String, GlobalKey> _dateSectionKeys = {};
  final Set<String> _activeDateKeys = {};

  // Memoized — creating the stream in build re-attached a Firestore listener
  // on every rebuild (e.g. while typing).
  late final Stream<QuerySnapshot> _messagesStream;

  @override
  void initState() {
    super.initState();
    NotificationEventService.setActiveConversationId(widget.conversationId);
    _messagesStream = _firestore
        .collection('conversations')
        .doc(widget.conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
    _loadCurrentUser();
    _loadOtherUserProfileImage();
    _resolveOtherUserTypeAndUid();
  }

  @override
  void dispose() {
    NotificationEventService.clearActiveConversationId(widget.conversationId);
    _msgController.dispose();
    _scrollController.dispose();
    _timestampVisibilityOverrides.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    // Get current user ID
    currentUserId = await InZoneDatabase.getCurrentUserUid();

    // Try to get current user's name
    if (currentUserId != null) {
      DocumentSnapshot userDoc =
          await _firestore.collection('humanUsers').doc(currentUserId).get();

      if (userDoc.exists && userDoc.data() != null) {
        var userData = userDoc.data() as Map<String, dynamic>;
        currentUserName = userData['name'] ?? userData['Name'] ?? "Me";
      }
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> _loadOtherUserProfileImage() async {
    try {
      if (widget.otherUserId.isEmpty) return;

      // First try from API
      final userData = await InZoneDatabase.getUserProfile(widget.otherUserId);
      if (userData != null &&
          userData['profilePicture'] != null &&
          userData['profilePicture'].toString().isNotEmpty &&
          mounted) {
        setState(() {
          _otherUserProfileImageUrl = userData['profilePicture'];
        });
        return;
      }

      // If API doesn't return a profile image or returns empty, try Firestore directly
      final userDoc = await FirebaseFirestore.instance
          .collection('humanUsers')
          .doc(widget.otherUserId)
          .get();

      if (userDoc.exists && userDoc.data() != null) {
        final userDocData = userDoc.data()!;
        final profilePic =
            userDocData['profilePicture'] ?? userDocData['profileImage'] ?? "";

        if (mounted && profilePic.toString().isNotEmpty) {
          setState(() {
            _otherUserProfileImageUrl = profilePic.toString();
          });
        }
      }
    } catch (e) {
      print('Error loading other user profile image: $e');
    }
  }

  Future<void> _resolveOtherUserTypeAndUid() async {
    try {
      final humanUsersRef = FirebaseFirestore.instance.collection('humanUsers');
      DocumentSnapshot<Map<String, dynamic>>? userDoc;

      final byId = await humanUsersRef.doc(widget.otherUserId).get();
      if (byId.exists) {
        userDoc = byId;
      } else {
        final byUsername = await humanUsersRef
            .where('username', isEqualTo: widget.otherUserId)
            .limit(1)
            .get();
        if (byUsername.docs.isNotEmpty) {
          userDoc = byUsername.docs.first;
        } else {
          final byUid = await humanUsersRef
              .where('uid', isEqualTo: widget.otherUserId)
              .limit(1)
              .get();
          if (byUid.docs.isNotEmpty) {
            userDoc = byUid.docs.first;
          } else {
            final byDocId = await humanUsersRef
                .where('user_document_id', isEqualTo: widget.otherUserId)
                .limit(1)
                .get();
            if (byDocId.docs.isNotEmpty) {
              userDoc = byDocId.docs.first;
            }
          }
        }
      }

      if (!mounted) return;

      if (userDoc != null && userDoc.exists) {
        final data = userDoc.data();
        setState(() {
          _isOtherUserHuman = true;
          _otherUserResolvedUid =
              data?['uid']?.toString().trim().isNotEmpty == true
                  ? data!['uid'].toString().trim()
                  : userDoc!.id;
        });
      } else {
        setState(() {
          _isOtherUserHuman = false;
          _otherUserResolvedUid = null;
        });
      }
    } catch (e) {
      debugPrint('Error resolving DM recipient type/uid: $e');
      if (!mounted) return;
      setState(() {
        _isOtherUserHuman = false;
        _otherUserResolvedUid = null;
      });
    }
  }

  void _openOtherUserProfileIfHuman() {
    final uid = _otherUserResolvedUid;
    if (!_isOtherUserHuman || uid == null || uid.isEmpty) return;
    context.push(Routes.regularProfilePath(uid));
  }

  String _dayKey(DateTime dateTime) {
    return DateFormat('yyyy-MM-dd').format(dateTime.toLocal());
  }

  DateTime _normalizeDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  bool _shouldAutoShowTimestamp({
    required DateTime current,
    required bool isToday,
    DateTime? next,
    String? nextSenderId,
    required String currentSenderId,
  }) {
    if (!isToday) return false;
    if (next == null) return true;
    if (nextSenderId != currentSenderId) return true;
    return next.difference(current).inMinutes >= 5;
  }

  String _formatVisibleTimestamp(DateTime dateTime) {
    return DateFormat('h:mm a').format(dateTime.toLocal());
  }

  String _formatExactTimestamp(DateTime dateTime) {
    return DateFormat('EEE, MMM d, yyyy • h:mm a').format(dateTime.toLocal());
  }

  void _toggleTimestampVisibility(String messageId) {
    final currentMap = _timestampVisibilityOverrides.value;
    final nextMap = Map<String, bool>.from(currentMap);
    final current = nextMap[messageId] ?? false;
    nextMap[messageId] = !current;
    _timestampVisibilityOverrides.value = nextMap;
  }

  bool _isNearBottom() {
    if (!_scrollController.hasClients) return true;
    return _scrollController.position.extentAfter < 160;
  }

  void _scheduleAutoScrollToLatest({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      if (!force && !_isNearBottom()) return;
      _scrollToLatestSettled(force: force);
    });
  }

  void _scrollToLatestSettled({bool force = false}) {
    if (!_scrollController.hasClients) return;

    final target = _scrollController.position.maxScrollExtent;
    if ((target - _scrollController.position.pixels).abs() < 1.0) return;

    if (force) {
      _scrollController.jumpTo(target);
      return;
    }

    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
    );
  }

  Future<void> _showMessageDetails({
    required BuildContext context,
    required String messageText,
    required DateTime? timestamp,
    required bool isMe,
    required String? statusLabel,
  }) async {
    if (timestamp == null) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(sheetContext).cardColor,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatExactTimestamp(timestamp),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(sheetContext).textTheme.bodyMedium?.color,
                  ),
                ),
                if (statusLabel != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(sheetContext).textTheme.bodySmall?.color,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  messageText,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(sheetContext).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _jumpToDate(DateTime dateTime) async {
    final key = _dateSectionKeys[_dayKey(dateTime)];
    if (key?.currentContext == null || !_scrollController.hasClients) return;

    final targetContext = key!.currentContext!;
    final renderObject = targetContext.findRenderObject();
    if (renderObject == null || !renderObject.attached) return;

    final viewport = RenderAbstractViewport.of(renderObject);

    final revealOffset = viewport.getOffsetToReveal(renderObject, 0.0).offset;
    final min = _scrollController.position.minScrollExtent;
    final max = _scrollController.position.maxScrollExtent;
    final targetOffset = revealOffset.clamp(min, max).toDouble();

    await _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  Future<void> _showDatePickerForJump() async {
    if (_activeDateKeys.isEmpty) return;

    final activeDates = _activeDateKeys
        .map((key) => DateFormat('yyyy-MM-dd').parse(key))
        .toList()
      ..sort();

    final now = DateTime.now().toLocal();
    final initialDate = activeDates.contains(_normalizeDate(now))
        ? _normalizeDate(now)
        : activeDates.last;

    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: activeDates.first,
      lastDate: activeDates.last,
      selectableDayPredicate: (date) {
        final normalized = _normalizeDate(date);
        return _activeDateKeys.contains(_dayKey(normalized));
      },
      helpText: 'Jump to date',
      confirmText: 'Go',
      cancelText: 'Cancel',
    );

    if (selected != null) {
      await _jumpToDate(selected);
    }
  }

  void _sendMessage() async {
    if (_isSendingMessage) return;

    final String messageText = _msgController.text.trim();

    // Require either text or pending media
    if (messageText.isEmpty && _pendingImage == null && _pendingVideo == null)
      {
        return;
      }
    if (currentUserId == null) return;

    setState(() {
      _isSendingMessage = true;
    });

    try {
      String? imageUrl;
      String? videoUrl;
      String? videoThumbnailUrl;

      // Upload pending media if exists
      if (_pendingImage != null) {
        imageUrl =
            await AuthWork.sendChatImage(widget.otherUserId, _pendingImage!);
      }
      if (_pendingVideo != null) {
        final result =
            await AuthWork.sendChatVideo(widget.otherUserId, _pendingVideo!);
        videoUrl = result['videoUrl'];
        videoThumbnailUrl = result['thumbnailUrl'];
      }

      // Reference to the conversation document
      final conversationRef =
          _firestore.collection('conversations').doc(widget.conversationId);

      // Create a new message document
      final newMessage = {
        'text': messageText,
        'senderId': currentUserId,
        'senderName': currentUserName,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      };

      // Add media URLs if present
      if (imageUrl != null) {
        newMessage['imageUrl'] = imageUrl;
      }
      if (videoUrl != null) {
        newMessage['videoUrl'] = videoUrl;
      }
      if (videoThumbnailUrl != null) {
        newMessage['videoThumbnailUrl'] = videoThumbnailUrl;
      }

      // Add message to the messages subcollection
      await conversationRef.collection('messages').add(newMessage);

      final lastMessageText = messageText;

      // Update conversation metadata
      await conversationRef.set({
        'lastMessage': lastMessageText,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'participants': [currentUserId, widget.otherUserId],
        'participantNames': {
          currentUserId: currentUserName,
          widget.otherUserId: widget.otherUserName,
        },
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Trigger DM notification event
      await NotificationEventService.onDirectMessage(
        widget.conversationId,
        lastMessageText,
        currentUserId!,
        widget.otherUserId,
      );

      // 🤖 AI ENGAGEMENT FIX: Check if receiver is an AI character and trigger immediate response
      await _checkAndTriggerAIResponse(lastMessageText);

      // Trigger DM notification
      // await NotificationService.sendDirectMessageNotification(
      //   chatId: widget.conversationId,
      //   content: _msgController.text.trim(),
      //   senderId: currentUserId!,
      //   receiverId: widget.otherUserId,
      // );

      // Fallback: ensure a notification doc exists in Firestore for the receiver even if the event endpoint is delayed or fails. Resolve the receiver to a canonical humanUsers uid (doc/uid/username) and write a deduplicated `direct_message` notification.
      try {
        final notifRef = FirebaseFirestore.instance.collection('notifications');

        final humanUsersRef =
            FirebaseFirestore.instance.collection('humanUsers');
        DocumentSnapshot? receiverDoc;
        String? resolvedReceiverUid;
        String resolvedReceiverName = widget.otherUserName;

        try {
          final byId = await humanUsersRef.doc(widget.otherUserId).get();
          if (byId.exists) {
            receiverDoc = byId;
          } else {
            final q1 = await humanUsersRef
                .where('username', isEqualTo: widget.otherUserId)
                .limit(1)
                .get();
            if (q1.docs.isNotEmpty) {
              receiverDoc = q1.docs.first;
            } else {
              final q2 = await humanUsersRef
                  .where('uid', isEqualTo: widget.otherUserId)
                  .limit(1)
                  .get();
              if (q2.docs.isNotEmpty) {
                receiverDoc = q2.docs.first;
              } else {
                final q3 = await humanUsersRef
                    .where('user_document_id', isEqualTo: widget.otherUserId)
                    .limit(1)
                    .get();
                if (q3.docs.isNotEmpty) receiverDoc = q3.docs.first;
              }
            }
          }

          if (receiverDoc != null && receiverDoc.exists) {
            final data = receiverDoc.data() as Map<String, dynamic>;
            resolvedReceiverUid = data['uid'] ?? receiverDoc.id;
            resolvedReceiverName =
                data['name'] ?? data['username'] ?? resolvedReceiverName;
            debugPrint(
                'Resolved DM receiver "${widget.otherUserId}" -> uid: $resolvedReceiverUid name: $resolvedReceiverName');
          } else {
            debugPrint(
                'Could not resolve DM receiver "${widget.otherUserId}" to humanUsers doc; skipping fallback notification');
          }
        } catch (e) {
          debugPrint(
              'Error resolving receiver for DM fallback notification: $e');
        }

        if (resolvedReceiverUid != null &&
            resolvedReceiverUid != currentUserId) {
          final query = await notifRef
              .where('userId', isEqualTo: resolvedReceiverUid)
              .where('data.chatId', isEqualTo: widget.conversationId)
              .where('data.senderId', isEqualTo: currentUserId)
              .limit(1)
              .get();

          if (query.docs.isEmpty) {
            final bodyText = _msgController.text.trim();
            final added = await notifRef.add({
              'userId': resolvedReceiverUid,
              'type': 'direct_message',
              'title': currentUserName,
              'body': bodyText.length > 100
                  ? '${bodyText.substring(0, 100)}...'
                  : bodyText,
              'isRead': false,
              'createdAt': FieldValue.serverTimestamp(),
              'data': {
                'chatId': widget.conversationId,
                'senderId': currentUserId,
                'senderName': currentUserName,
                'messageContent': bodyText,
              },
              // deeplink removed per notification deeplink deprecation
            });

            debugPrint(
                'Fallback DM notification written: ${added.id} -> user $resolvedReceiverUid');
          }
        }
      } catch (e) {
        debugPrint('Failed to write fallback DM notification: $e');
      }

      _msgController.clear();
      setState(() {
        _pendingImage = null;
        _pendingVideo = null;
      });
      _scrollToEnd();
    } catch (e) {
      print('Error sending message: $e');
      ToastService.showToast(
        context,
        backgroundColor: Theme.of(context).canvasColor,
        shadowColor: Colors.transparent,
        leading: const Icon(
          Icons.error,
          color: Colors.redAccent,
        ),
        message: 'Failed to send message. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSendingMessage = false;
        });
      }
    }
  }

  void _scrollToEnd() {
    _scheduleAutoScrollToLatest(force: true);
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.otherUserName),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          leadingWidth: 50,
          leading: Padding(
            padding: const EdgeInsets.only(left: 12.0),
            child: GestureDetector(
              onTap: () {
                context.pop();
              },
              child: CircleAvatar(
                radius: 22,
                backgroundColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey.shade800
                    : Colors.grey.shade200,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Center(
                    child: Icon(
                      Icons.arrow_back_ios,
                      size: 18,
                      color: Theme.of(context).iconTheme.color,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).canvasColor,
      appBar: ChatAppBar(
        title: widget.otherUserName,
        avatarId: widget.otherUserId,
        avatarUrl: _otherUserProfileImageUrl,
        onBack: () => context.pop(),
        onAvatarTap: _isOtherUserHuman ? _openOtherUserProfileIfHuman : null,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                      child: Text("No messages yet. Say hello!"));
                }

                final messages = snapshot.data!.docs;
                final messageWidgets = <Widget>[];
                final activeDayKeys = <String>{};

                final sortedMessages = List<QueryDocumentSnapshot>.from(
                    messages)
                  ..sort((a, b) {
                    final aData = a.data() as Map<String, dynamic>;
                    final bData = b.data() as Map<String, dynamic>;
                    final aTs = (aData['timestamp'] as Timestamp?)?.toDate();
                    final bTs = (bData['timestamp'] as Timestamp?)?.toDate();
                    if (aTs == null && bTs == null) return a.id.compareTo(b.id);
                    if (aTs == null) return 1;
                    if (bTs == null) return -1;
                    final byTime = aTs.compareTo(bTs);
                    if (byTime != 0) return byTime;
                    return a.id.compareTo(b.id);
                  });
                final insertedDayHeaderKeys = <String>{};

                for (int index = 0; index < sortedMessages.length; index++) {
                  final message = sortedMessages[index];
                  final messageData = message.data() as Map<String, dynamic>;
                  final senderId = messageData['senderId']?.toString() ?? '';
                  final messageText = messageData['text']?.toString() ?? '';
                  final senderName =
                      messageData['senderName']?.toString() ?? '';
                  final Timestamp? timestamp =
                      messageData['timestamp'] as Timestamp?;
                  final imageUrl = messageData['imageUrl']?.toString();
                  final videoUrl = messageData['videoUrl']?.toString();
                  final videoThumbnailUrl =
                      messageData['videoThumbnailUrl']?.toString();
                  final bool isMe = senderId == currentUserId;
                  final DateTime? messageDateTime =
                      timestamp?.toDate().toLocal();
                  final String messageId = message.id;

                  if (messageDateTime != null) {
                    final dayKey = _dayKey(messageDateTime);
                    activeDayKeys.add(dayKey);

                    if (!insertedDayHeaderKeys.contains(dayKey)) {
                      insertedDayHeaderKeys.add(dayKey);
                      final headerDate = _normalizeDate(messageDateTime);
                      final sectionKey = _dateSectionKeys.putIfAbsent(
                          dayKey, () => GlobalKey());

                      messageWidgets.add(
                        KeyedSubtree(
                          key: sectionKey,
                          child: DateHeader(
                            dateTime: headerDate,
                            showArrow: true,
                            onTap: _showDatePickerForJump,
                          ),
                        ),
                      );
                    }

                    final QueryDocumentSnapshot? nextMessage =
                        (index + 1 < sortedMessages.length)
                            ? sortedMessages[index + 1]
                            : null;
                    final nextData =
                        nextMessage?.data() as Map<String, dynamic>?;
                    final DateTime? nextTimestamp =
                        (nextData?['timestamp'] as Timestamp?)
                            ?.toDate()
                            .toLocal();
                    final bool isToday =
                        _dayKey(messageDateTime) == _dayKey(DateTime.now());
                    final bool autoShowTimestamp = _shouldAutoShowTimestamp(
                      current: messageDateTime,
                      isToday: isToday,
                      next: nextTimestamp,
                      nextSenderId: nextData?['senderId']?.toString(),
                      currentSenderId: senderId,
                    );
                    final bool isLatestOwnMessage =
                        isMe && index == (sortedMessages.length - 1);
                    final String? statusLabel = isLatestOwnMessage
                        ? (messageData['isRead'] == true ? 'Read' : 'Sent')
                        : null;

                    messageWidgets.add(
                      ValueListenableBuilder<Map<String, bool>>(
                        key: ValueKey('msg_$messageId'),
                        valueListenable: _timestampVisibilityOverrides,
                        builder: (context, overrides, _) {
                          final showTimestamp =
                              overrides[messageId] ?? autoShowTimestamp;
                          return MessageBubble(
                            message: messageText,
                            isMe: isMe,
                            timestamp: messageDateTime,
                            timestampLabel: showTimestamp
                                ? _formatVisibleTimestamp(messageDateTime)
                                : null,
                            showTimestamp: showTimestamp,
                            statusLabel: statusLabel,
                            senderName: isMe ? null : senderName,
                            senderAvatar: isMe
                                ? null
                                : Container(
                                    width: 35,
                                    height: 35,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Theme.of(context).cardColor,
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: _otherUserProfileImageUrl.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: _otherUserProfileImageUrl,
                                            width: 35,
                                            height: 35,
                                            fit: BoxFit.cover,
                                          )
                                        : const Center(
                                            child: Icon(Icons.account_circle,
                                                size: 35),
                                          ),
                                  ),
                            imageUrl: imageUrl,
                            videoUrl: videoUrl,
                            videoThumbnailUrl: videoThumbnailUrl,
                            onSenderTap: _isOtherUserHuman
                                ? _openOtherUserProfileIfHuman
                                : null,
                            onTap: () => _toggleTimestampVisibility(messageId),
                            onLongPress: () =>
                                _toggleTimestampVisibility(messageId),
                          );
                        },
                      ),
                    );
                  }
                }

                _activeDateKeys
                  ..clear()
                  ..addAll(activeDayKeys);

                _dateSectionKeys
                    .removeWhere((key, _) => !activeDayKeys.contains(key));

                final lastData = messages.last.data() as Map<String, dynamic>;
                final lastTs = (lastData['timestamp'] as Timestamp?)
                        ?.millisecondsSinceEpoch ??
                    0;
                final snapshotSignature =
                    '${messages.length}_${messages.last.id}_$lastTs';
                final dataChanged = snapshotSignature != _lastSnapshotSignature;

                if (dataChanged) {
                  _lastSnapshotSignature = snapshotSignature;
                }

                final shouldAutoScroll =
                    dataChanged && (!_didInitialAutoScroll || _isNearBottom());
                if (messages.length != _lastRenderedMessageCount ||
                    shouldAutoScroll) {
                  _lastRenderedMessageCount = messages.length;
                  if (shouldAutoScroll) {
                    _scheduleAutoScrollToLatest(force: !_didInitialAutoScroll);
                  }
                  _didInitialAutoScroll = true;
                }

                return SingleChildScrollView(
                  controller: _scrollController,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                    child: Column(
                      children: messageWidgets,
                    ),
                  ),
                );
              },
            ),
          ),
          ChatInput(
            controller: _msgController,
            onSend: _sendMessage,
            pendingImage: _pendingImage,
            pendingVideo: _pendingVideo,
            onClearMedia: () {
              setState(() {
                _pendingImage = null;
                _pendingVideo = null;
              });
            },
            onImagePicked: (File imageFile) {
              setState(() {
                _pendingImage = imageFile;
                _pendingVideo = null;
              });
            },
            onVideoPicked: (File videoFile) {
              setState(() {
                _pendingVideo = videoFile;
                _pendingImage = null;
              });
            },
          ),
        ],
      ),
    );
  }

  String _getDateKey(DateTime dateTime) {
    final now = DateTime.now().toUtc();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate == today) {
      return 'Today';
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('MMMM d, yyyy').format(dateTime.toLocal());
    }
  }

  /// 🤖 AI ENGAGEMENT FIX: Check if receiver is an AI character and trigger immediate response
  Future<void> _checkAndTriggerAIResponse(String messageText) async {
    try {
      // Check if the other user is an AI character by looking in popularCharacters collection
      final aiCharacterDoc = await FirebaseFirestore.instance
          .collection('popularCharacters')
          .doc(widget.otherUserId)
          .get();

      if (aiCharacterDoc.exists) {
        print('🤖 Detected message to AI character: ${widget.otherUserName}');
        print('🚀 Triggering immediate AI response...');
        // Trigger immediate AI response
        final result = await AIEngagementService.triggerDMAutoResponse(
          userId: currentUserId!,
          aiCharacterId: widget.otherUserId,
          messageText: messageText,
          conversationId: widget.conversationId,
        );

        if (result['success'] == true) {
          print('✅ AI auto-response triggered successfully');
        } else {
          print('❌ AI auto-response failed: ${result['error']}');
          // Don't show error to user - this is a background process
        }
      } else {
        print('👤 Message to human user - no AI response needed');
      }
    } catch (e) {
      print('❌ Error checking for AI character: $e');
      // Don't show error to user - this is a background process
    }
  }
}