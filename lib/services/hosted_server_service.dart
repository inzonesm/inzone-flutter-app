import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:inzone/data/hosted_server.dart';

/// Firestore access for the community server directory (`hostedServers`
/// collection). Mirrors the CommunityGameService conventions: server-side
/// status filter, defensive client-side field checks, newest first.
class HostedServerService {
  HostedServerService._();

  static CollectionReference<Map<String, dynamic>> get _collection =>
      FirebaseFirestore.instance.collection('hostedServers');

  static Future<List<HostedServer>> fetchAll() async {
    // Sorted client-side: a server-side where+orderBy pair would require a
    // composite index on the (new) collection before it works in production.
    final snapshot = await _collection
        .where('status', isEqualTo: 'approved')
        .limit(100)
        .get();
    final servers = snapshot.docs
        .map(HostedServer.fromSnapshot)
        .where((s) => s.name.isNotEmpty && s.host.isNotEmpty && s.port > 0)
        .toList()
      ..sort((a, b) {
        final at = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bt = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bt.compareTo(at);
      });
    return servers;
  }

  static Future<void> addServer(HostedServer server) {
    return _collection.add(server.toCreateMap());
  }

  static Future<void> deleteServer(String id) {
    return _collection.doc(id).delete();
  }
}
