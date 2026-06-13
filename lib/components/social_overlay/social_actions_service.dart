import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inzone/data/community_game.dart';
import 'package:inzone/data/group_chat_data.dart';
import 'package:inzone/services/appsflyer_service.dart';
import 'package:inzone/services/group_chat_service.dart';
import 'package:inzone/services/inzone_database.dart';
import 'package:share_plus/share_plus.dart';

/// Single backend integration point for the social overlay. Every method
/// reuses an existing inzone-flutter-app service — no new endpoints:
///
///  - [sendChallenge]     → the native OS share sheet (`SharePlus`), with
///                          the prewritten message + AppsFlyer OneLink.
///  - [groupChatStream] / [sendChatMessage]
///                        → `GroupChatService` (`groupChats` collection),
///                          same path the `open-chat` endpoint targets.
///  - [createScorePost]   → `InZoneDatabase.createRepost`, the exact same
///                          call the simula Game Over popup's
///                          "Share Progress" → PostChatScreen flow makes.
class SocialActionsService {
  SocialActionsService({
    required this.game,
    this.groupChatId,
  });

  final CommunityGame game;

  /// Explicit group chat override. When null, resolved by querying `groupChats`
  /// for a document whose ID starts with `game_${game.id}_`.
  final String? groupChatId;

  String? _resolvedGroupChatId;

  /// Finds the game's dedicated group chat by querying `groupChats` for docs
  /// whose ID starts with `game_${game.id}_` (e.g. `game_social-loops_17…`).
  Future<String> _resolveGroupChatId() async {
    if (_resolvedGroupChatId != null) return _resolvedGroupChatId!;
    if (groupChatId != null) return _resolvedGroupChatId = groupChatId!;

    // Doc IDs look like game_social-loops_1779919799186. Upper bound
    // replaces trailing _ (0x5F) with backtick (0x60) to cover all timestamps.
    final prefix = 'game_${game.id}_';
    final prefixEnd = 'game_${game.id}`';
    try {
      final snap = await FirebaseFirestore.instance
          .collection('groupChats')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: prefix)
          .where(FieldPath.documentId, isLessThan: prefixEnd)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        return _resolvedGroupChatId = snap.docs.first.id;
      }
    } catch (_) {}

    return _resolvedGroupChatId = GroupChatService.defaultGroupChatDocId;
  }

  // ---------------------------------------------------------------------
  // Prewritten messages
  // ---------------------------------------------------------------------

  String prewrittenMessage(int? score) => score != null
      ? 'I just scored $score in ${game.name} on InZone — think you can beat me? 🎮'
      : "I'm playing ${game.name} on InZone — come play with me! 🎮";

  /// AppsFlyer OneLink. `deep_link_sub1` carries the game id; the deep-link
  /// handler already checks `html_games` first and opens community games in
  /// CommunityGameScreen (see appsflyer_service.dart).
  String challengeLink() => AppsFlyerService().generateMinigameLink(game.id);

  // ---------------------------------------------------------------------
  // 1. Send challenge — opens the device's native OS share sheet
  // ---------------------------------------------------------------------

  Future<void> sendChallenge(int? score) {
    return SharePlus.instance.share(
      ShareParams(
        text: '${prewrittenMessage(score)}\n${challengeLink()}',
        subject: 'Challenge me on ${game.name}',
      ),
    );
  }

  // ---------------------------------------------------------------------
  // 2. Open chat  (= existing open-chat endpoint target)
  // ---------------------------------------------------------------------

  Stream<GroupChatData> groupChatStream() {
    return Stream.fromFuture(_resolveGroupChatId()).asyncExpand((id) {
      return GroupChatService.getGroupChatStreamById(id)
          .where((snap) => snap.exists)
          .map(GroupChatData.fromSnapshot);
    });
  }

  Future<void> sendChatMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final id = await _resolveGroupChatId();
    return GroupChatService.sendMessageToGroup(id, trimmed);
  }

  // ---------------------------------------------------------------------
  // 3. Share score to InZone posts  (= Game Over popup's share flow)
  // ---------------------------------------------------------------------

  /// Creates a home-feed post via `InZoneDatabase.createRepost` — identical
  /// shape to the minigame "Share Progress" flow, so it renders with the
  /// existing repost card. Returns the createRepost result map
  /// (`success` / `sentiment` / `blocked`), which the composer surfaces.
  Future<Map<String, dynamic>> createScorePost(String text, int? score) {
    final icon = game.iconUrl.trim();
    return InZoneDatabase.createRepost(
      content: text.trim(),
      aiName: game.name,
      aiProfileImageURL: icon,
      aiChatContent: score != null
          ? 'Scored $score in ${game.name}.'
          : 'Played ${game.name}.',
      aiId: game.id,
      imageRefs: icon.isNotEmpty ? [icon] : const [],
      videoRefs: const [],
      minigameLink: challengeLink(),
    );
  }
}