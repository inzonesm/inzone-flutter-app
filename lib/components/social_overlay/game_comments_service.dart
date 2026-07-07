import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:inzone/data/community_game.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Per-game comments for community (HTML / Unity WebGL) games.
///
/// This is the Flutter twin of the InZone Games website's engagement layer
/// (`inzone-games/lib/engagement.ts`) and reads/writes the exact same
/// Firestore subcollection, so comments posted on the website and in the app
/// are one shared thread:
///
///   html_games/{gameId}/comments/{autoId}
///     authorId, authorName, anonymous, text,
///     parentId (null for top-level), likeCount, createdAt
///
/// The matching rules in inzone-games/firestore.rules are guest-friendly by
/// design: creates need only the right shape (text ≤ 500 chars, likeCount 0)
/// and updates may only move `likeCount`. Per-user "have I liked this"
/// state is kept client-side (SharedPreferences here, localStorage on the
/// web), exactly like the website.
class GameCommentsService {
  GameCommentsService({required this.game});

  final CommunityGame game;

  /// Longest comment we accept — mirrored in firestore.rules and the website.
  static const int maxCommentLen = 500;

  static const String _collection = 'html_games';
  static const String _likedPrefsPrefix = 'inzone_game_comment_likes_';
  static const String _guestIdPrefsKey = 'inzone_guest_id';

  CollectionReference<Map<String, dynamic>> get _comments =>
      FirebaseFirestore.instance
          .collection(_collection)
          .doc(game.id)
          .collection('comments');

  // ---------------------------------------------------------------------
  // Identity
  // ---------------------------------------------------------------------

  /// The acting user: the signed-in Firebase user when available, otherwise a
  /// persisted per-install `guest_…` id — the same actor model the website
  /// uses so guests can participate without signing in.
  Future<GameCommentIdentity> resolveIdentity() async {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName?.trim();
    if (user != null) {
      return GameCommentIdentity(
        id: user.uid,
        username: (displayName != null && displayName.isNotEmpty)
            ? displayName
            : 'Player',
        anonymous: false,
      );
    }
    final prefs = await SharedPreferences.getInstance();
    var guestId = prefs.getString(_guestIdPrefsKey);
    if (guestId == null || guestId.isEmpty) {
      guestId = 'guest_${DateTime.now().microsecondsSinceEpoch}';
      await prefs.setString(_guestIdPrefsKey, guestId);
    }
    return GameCommentIdentity(id: guestId, username: 'Player', anonymous: true);
  }

  // ---------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------

  /// Newest-first list of comments for the game. Best-effort → [] on failure.
  Future<List<GameComment>> fetchComments({int max = 200}) async {
    if (game.id.isEmpty) return const [];
    try {
      final snap = await _comments
          .orderBy('createdAt', descending: true)
          .limit(max)
          .get();
      return snap.docs.map((d) => GameComment.fromDoc(d.id, d.data())).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Just the comment count (server-side COUNT, no payloads). Best-effort → 0.
  Future<int> fetchCommentCount() async {
    if (game.id.isEmpty) return 0;
    try {
      final snap = await _comments.count().get();
      return snap.count ?? 0;
    } catch (_) {
      return 0;
    }
  }

  // ---------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------

  /// Post a comment (or a reply when [parentId] is set). Returns the created
  /// comment with a local timestamp so it renders immediately. Throws on
  /// empty/oversized text so the caller can surface a message.
  Future<GameComment> addComment(String rawText, {String? parentId}) async {
    final text = rawText.trim();
    if (game.id.isEmpty) throw StateError('Missing game.');
    if (text.isEmpty) throw StateError('Comment is empty.');
    if (text.length > maxCommentLen) {
      throw StateError('Keep it under $maxCommentLen characters.');
    }

    final actor = await resolveIdentity();
    final ref = await _comments.add({
      'authorId': actor.id,
      'authorName': actor.username,
      'anonymous': actor.anonymous,
      'text': text,
      'parentId': parentId,
      'likeCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return GameComment(
      id: ref.id,
      authorId: actor.id,
      authorName: actor.username,
      anonymous: actor.anonymous,
      text: text,
      parentId: parentId,
      likeCount: 0,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Bump a comment's like tally by ±1 (atomic). Best-effort — a denied write
  /// is surfaced to the caller's optimistic flow via the thrown error.
  Future<void> likeComment(String commentId, bool liked) async {
    if (game.id.isEmpty || commentId.isEmpty) return;
    await _comments.doc(commentId).update({
      'likeCount': FieldValue.increment(liked ? 1 : -1),
    });
  }

  // ---------------------------------------------------------------------
  // Local "which comments have I liked" memory (mirrors the website's
  // localStorage behavior — the shared tally lives on the server, the
  // per-user flag lives on the device).
  // ---------------------------------------------------------------------

  Future<Set<String>> getLikedCommentIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getStringList('$_likedPrefsPrefix${game.id}') ?? const [])
          .toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> setCommentLiked(String commentId, bool liked) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_likedPrefsPrefix${game.id}';
      final ids = (prefs.getStringList(key) ?? const []).toSet();
      liked ? ids.add(commentId) : ids.remove(commentId);
      await prefs.setStringList(key, ids.toList());
    } catch (_) {
      // Best-effort; losing this only forgets the local liked highlight.
    }
  }
}

/// Who is commenting — signed-in user or per-install guest.
class GameCommentIdentity {
  const GameCommentIdentity({
    required this.id,
    required this.username,
    required this.anonymous,
  });

  final String id;
  final String username;
  final bool anonymous;
}

/// One comment (or reply) on a community game — same shape as the website's
/// `GameComment` in `inzone-games/lib/engagement.ts`.
class GameComment {
  GameComment({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.anonymous,
    required this.text,
    required this.parentId,
    required this.likeCount,
    required this.createdAt,
  });

  factory GameComment.fromDoc(String id, Map<String, dynamic> raw) {
    final created = raw['createdAt'];
    final parent = raw['parentId'];
    final likes = raw['likeCount'];
    final authorName = (raw['authorName'] as String? ?? '').trim();
    return GameComment(
      id: id,
      authorId: (raw['authorId'] as String? ?? '').trim(),
      authorName: authorName.isEmpty ? 'Player' : authorName,
      anonymous: raw['anonymous'] == true,
      text: (raw['text'] as String? ?? '').trim(),
      parentId: (parent is String && parent.isNotEmpty) ? parent : null,
      likeCount: (likes is num && likes > 0) ? likes.toInt() : 0,
      createdAt: created is Timestamp ? created.millisecondsSinceEpoch : null,
    );
  }

  final String id;
  final String authorId;
  final String authorName;
  final bool anonymous;
  final String text;

  /// Parent comment id for a reply, or null for a top-level comment.
  final String? parentId;

  /// Denormalized like tally (moved atomically on the server).
  int likeCount;

  /// Epoch millis, or null while the server timestamp is still pending.
  final int? createdAt;
}
