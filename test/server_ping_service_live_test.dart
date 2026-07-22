// Live-network smoke test for ServerPingService (Java SLP, Bedrock RakNet
// ping, hosted fallback, TTL cache). Hits real public servers — run manually:
//   flutter test test/server_ping_service_live_test.dart
@Tags(['live-network'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:inzone/services/server_ping_service.dart';

void main() {
  test('Java SLP ping against a live public server', () async {
    final status = await ServerPingService.fetchStatus(
        host: 'mc.hypixel.net', port: 25565, bedrock: false);
    expect(status.online, isTrue);
    expect(status.playersMax, greaterThan(0));
    expect(status.version, isNotEmpty);
    // ignore: avoid_print
    print('JAVA players=${status.playersOnline}/${status.playersMax} '
        'version="${status.version}" motd="${status.motd}" '
        'src=${status.source} lat=${status.latencyMs}ms');
  });

  test('Bedrock RakNet ping against a live public server', () async {
    final status = await ServerPingService.fetchStatus(
        host: 'geo.hivebedrock.network', port: 19132, bedrock: true);
    expect(status.online, isTrue);
    expect(status.playersMax, greaterThan(0));
    // ignore: avoid_print
    print('BEDROCK players=${status.playersOnline}/${status.playersMax} '
        'version="${status.version}" motd="${status.motd}" '
        'src=${status.source} lat=${status.latencyMs}ms');
  });

  test('Geyser crossplay probe on a Java-only host', () async {
    final crossplay =
        await ServerPingService.probeBedrockCrossplay('mc.hypixel.net');
    // Hypixel has no Bedrock endpoint; just assert the probe returns.
    // ignore: avoid_print
    print('CROSSPLAY hypixel=${crossplay != null}');
  });

  test('unreachable host resolves to offline (via fallback path)', () async {
    final status = await ServerPingService.fetchStatus(
        host: 'definitely-not-a-real-server-xyz.example',
        port: 25565,
        bedrock: false);
    expect(status.online, isFalse);
  });

  test('second fetch within TTL returns the cached instance', () async {
    final first = await ServerPingService.fetchStatus(
        host: 'mc.hypixel.net', port: 25565, bedrock: false);
    final second = await ServerPingService.fetchStatus(
        host: 'mc.hypixel.net', port: 25565, bedrock: false);
    expect(identical(first, second), isTrue);
  });
}
