import 'package:simula_ads/simula_ads.dart';
import 'package:inzone/data/community_game.dart';

enum HubGameSource { simula, community }

class HubGame {
  final HubGameSource source;
  final GameData? simulaGame;
  final CommunityGame? communityGame;

  HubGame.simula(GameData game)
      : source = HubGameSource.simula,
        simulaGame = game,
        communityGame = null;

  HubGame.community(CommunityGame game)
      : source = HubGameSource.community,
        simulaGame = null,
        communityGame = game;

  String get id =>
      source == HubGameSource.simula ? simulaGame!.id : communityGame!.id;

  String get name =>
      source == HubGameSource.simula ? simulaGame!.name : communityGame!.name;

  String get iconUrl => source == HubGameSource.simula
      ? simulaGame!.iconUrl
      : communityGame!.iconUrl;

  String get description => source == HubGameSource.simula
      ? simulaGame!.description
      : communityGame!.description;

  String? get iconFallback =>
      source == HubGameSource.simula ? simulaGame!.iconFallback : null;
}
