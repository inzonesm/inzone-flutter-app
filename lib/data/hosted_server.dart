import 'package:cloud_firestore/cloud_firestore.dart';

/// Which client/protocol a community-hosted server speaks. Determines how we
/// ping it for live status and whether a tap-to-join deep link is possible.
enum ServerGameType { minecraftJava, minecraftBedrock, other }

ServerGameType serverGameTypeFromString(String? raw) {
  switch (raw) {
    case 'minecraft_java':
      return ServerGameType.minecraftJava;
    case 'minecraft_bedrock':
      return ServerGameType.minecraftBedrock;
    default:
      return ServerGameType.other;
  }
}

String serverGameTypeToString(ServerGameType type) {
  switch (type) {
    case ServerGameType.minecraftJava:
      return 'minecraft_java';
    case ServerGameType.minecraftBedrock:
      return 'minecraft_bedrock';
    case ServerGameType.other:
      return 'other';
  }
}

/// A community-registered multiplayer game server (Firestore `hostedServers`).
/// Typically a server the uploader rents at BisectHosting, but any reachable
/// host:port works — the hub only needs an address to ping and share.
class HostedServer {
  final String id;
  final String name;
  final String description;
  final ServerGameType gameType;

  /// Display name of the game for [ServerGameType.other] entries
  /// (e.g. "Terraria", "Palworld"). Empty for Minecraft types.
  final String gameName;
  final String host;
  final int port;

  /// Optional companion web map (BlueMap/Dynmap) URL, shown in a webview.
  final String mapUrl;
  final String uploaderId;
  final DateTime? createdAt;

  const HostedServer({
    required this.id,
    required this.name,
    required this.description,
    required this.gameType,
    required this.gameName,
    required this.host,
    required this.port,
    required this.mapUrl,
    required this.uploaderId,
    required this.createdAt,
  });

  String get address => '$host:$port';

  bool get isMinecraft =>
      gameType == ServerGameType.minecraftJava ||
      gameType == ServerGameType.minecraftBedrock;

  String get gameLabel {
    switch (gameType) {
      case ServerGameType.minecraftJava:
        return 'Minecraft: Java Edition';
      case ServerGameType.minecraftBedrock:
        return 'Minecraft: Bedrock Edition';
      case ServerGameType.other:
        return gameName.isNotEmpty ? gameName : 'Game server';
    }
  }

  factory HostedServer.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return HostedServer(
      id: snapshot.id,
      name: (data['name'] as String?)?.trim() ?? '',
      description: (data['description'] as String?)?.trim() ?? '',
      gameType: serverGameTypeFromString(data['gameType'] as String?),
      gameName: (data['gameName'] as String?)?.trim() ?? '',
      host: (data['host'] as String?)?.trim() ?? '',
      port: (data['port'] as num?)?.toInt() ?? 0,
      mapUrl: (data['mapUrl'] as String?)?.trim() ?? '',
      uploaderId: (data['uploaderId'] as String?) ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toCreateMap() => {
        'name': name,
        'description': description,
        'gameType': serverGameTypeToString(gameType),
        'gameName': gameName,
        'host': host,
        'port': port,
        'mapUrl': mapUrl,
        'uploaderId': uploaderId,
        'status': 'approved',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
