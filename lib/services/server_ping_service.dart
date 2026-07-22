import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Live status of a game server, from a direct protocol ping or a hosted
/// status API fallback.
class ServerStatus {
  final bool online;
  final String motd;
  final int playersOnline;
  final int playersMax;
  final String version;
  final int latencyMs;

  /// 'ping' for a direct in-app protocol exchange, 'mcstatus.io' for the
  /// hosted fallback API.
  final String source;

  const ServerStatus({
    required this.online,
    this.motd = '',
    this.playersOnline = 0,
    this.playersMax = 0,
    this.version = '',
    this.latencyMs = 0,
    this.source = 'ping',
  });

  static const offline = ServerStatus(online: false);
}

/// Queries Minecraft servers directly from the device — Java Edition via the
/// Server List Ping TCP exchange, Bedrock via a RakNet unconnected ping (UDP).
/// Falls back to the free api.mcstatus.io service when the direct ping fails
/// (e.g. UDP-hostile carrier NAT). Results are cached for [_cacheTtl] so hub
/// lists don't re-ping on every rebuild (same TTL-cache convention as the
/// rest of the app's live signals).
class ServerPingService {
  ServerPingService._();

  static const Duration _pingTimeout = Duration(seconds: 4);
  static const Duration _cacheTtl = Duration(seconds: 60);
  static const int bedrockDefaultPort = 19132;
  static const int javaDefaultPort = 25565;

  static final Map<String, ({DateTime at, ServerStatus status})> _cache = {};
  static final Map<String, Future<ServerStatus>> _inFlight = {};

  /// Fetch (and cache) the status of a Minecraft server.
  static Future<ServerStatus> fetchStatus({
    required String host,
    required int port,
    required bool bedrock,
  }) {
    final key = '$host:$port:${bedrock ? 'bedrock' : 'java'}';
    final cached = _cache[key];
    if (cached != null && DateTime.now().difference(cached.at) < _cacheTtl) {
      return Future.value(cached.status);
    }
    final inFlight = _inFlight[key];
    if (inFlight != null) return inFlight;

    final future = _fetchAndCache(key, host: host, port: port, bedrock: bedrock);
    _inFlight[key] = future;
    return future;
  }

  static Future<ServerStatus> _fetchAndCache(
    String key, {
    required String host,
    required int port,
    required bool bedrock,
  }) async {
    try {
      final status =
          await _fetchStatusUncached(host: host, port: port, bedrock: bedrock);
      _cache[key] = (at: DateTime.now(), status: status);
      return status;
    } finally {
      _inFlight.remove(key);
    }
  }

  /// Probe whether a (Java) server also answers Bedrock pings on the default
  /// Bedrock port — i.e. it runs a Geyser crossplay proxy, so mobile players
  /// can join it. Returns the Bedrock status when detected, null otherwise.
  static Future<ServerStatus?> probeBedrockCrossplay(String host) async {
    try {
      final status = await fetchStatus(
        host: host,
        port: bedrockDefaultPort,
        bedrock: true,
      );
      return status.online ? status : null;
    } catch (_) {
      return null;
    }
  }

  static Future<ServerStatus> _fetchStatusUncached({
    required String host,
    required int port,
    required bool bedrock,
  }) async {
    try {
      return bedrock
          ? await _pingBedrock(host, port)
          : await _pingJava(host, port);
    } catch (_) {
      // Direct ping failed — try the hosted status API before declaring the
      // server offline (it may just be that this network blocks the protocol).
      try {
        return await _fetchFromMcstatusIo(host, port, bedrock);
      } catch (_) {
        return ServerStatus.offline;
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Java Edition: Server List Ping (TCP, VarInt-framed packets, JSON payload).
  // Handshake(0x00, protocol=-1, host, port, nextState=1) + StatusRequest(0x00)
  // -> StatusResponse(0x00, JSON string).
  // ---------------------------------------------------------------------------

  static Future<ServerStatus> _pingJava(String host, int port) async {
    final stopwatch = Stopwatch()..start();
    final socket = await Socket.connect(host, port, timeout: _pingTimeout);
    final completer = Completer<ServerStatus>();
    final buffer = BytesBuilder(copy: false);
    late final Timer timer;
    StreamSubscription<List<int>>? sub;

    void finish(ServerStatus? status, [Object? error]) {
      if (completer.isCompleted) return;
      timer.cancel();
      sub?.cancel();
      socket.destroy();
      if (status != null) {
        completer.complete(status);
      } else {
        completer.completeError(error ?? const SocketException('ping failed'));
      }
    }

    timer = Timer(_pingTimeout, () {
      finish(null, TimeoutException('Java ping timed out'));
    });

    sub = socket.listen(
      (chunk) {
        buffer.add(chunk);
        try {
          final status = _tryParseJavaResponse(
            buffer.toBytes(),
            stopwatch.elapsedMilliseconds,
          );
          if (status != null) finish(status);
        } catch (e) {
          // Complete-length packet with garbage JSON (broken/hostile server):
          // fail over to the hosted API instead of raising in the zone.
          finish(null, e);
        }
      },
      onError: (Object e) => finish(null, e),
      onDone: () => finish(null),
      cancelOnError: true,
    );

    try {
      final hostBytes = utf8.encode(host);
      final body = BytesBuilder(copy: false)
        ..addByte(0x00)
        ..add(_encodeVarInt(-1))
        ..add(_encodeVarInt(hostBytes.length))
        ..add(hostBytes)
        ..addByte((port >> 8) & 0xFF)
        ..addByte(port & 0xFF)
        ..add(_encodeVarInt(1));
      final bodyBytes = body.takeBytes();
      socket.add([..._encodeVarInt(bodyBytes.length), ...bodyBytes]);
      socket.add(const [0x01, 0x00]); // StatusRequest, VarInt-framed.
    } catch (e) {
      finish(null, e);
    }

    return completer.future;
  }

  /// Attempts to decode a complete StatusResponse from the bytes received so
  /// far. Returns null while the packet is still incomplete.
  static ServerStatus? _tryParseJavaResponse(List<int> data, int latencyMs) {
    var offset = 0;
    final packetLength = _decodeVarInt(data, offset);
    if (packetLength == null) return null;
    offset = packetLength.next;
    if (data.length - offset < packetLength.value) return null;

    final packetId = _decodeVarInt(data, offset);
    if (packetId == null || packetId.value != 0x00) return null;
    offset = packetId.next;

    final jsonLength = _decodeVarInt(data, offset);
    if (jsonLength == null) return null;
    offset = jsonLength.next;
    if (data.length - offset < jsonLength.value) return null;

    final payload = utf8.decode(
      data.sublist(offset, offset + jsonLength.value),
      allowMalformed: true,
    );
    final decoded = jsonDecode(payload);
    if (decoded is! Map<String, dynamic>) return null;

    final players = decoded['players'];
    final version = decoded['version'];
    return ServerStatus(
      online: true,
      motd: _flattenMotd(decoded['description']),
      playersOnline: players is Map ? (players['online'] as num?)?.toInt() ?? 0 : 0,
      playersMax: players is Map ? (players['max'] as num?)?.toInt() ?? 0 : 0,
      version: version is Map ? (version['name'] as String?) ?? '' : '',
      latencyMs: latencyMs,
    );
  }

  /// Minecraft chat components can be a plain string or a nested
  /// {text, extra: [...]} tree; flatten to plain text and strip § color codes.
  static String _flattenMotd(dynamic description) {
    String flatten(dynamic node) {
      if (node == null) return '';
      if (node is String) return node;
      if (node is Map) {
        final out = StringBuffer(node['text'] ?? '');
        final extra = node['extra'];
        if (extra is List) {
          for (final child in extra) {
            out.write(flatten(child));
          }
        }
        return out.toString();
      }
      return '';
    }

    return flatten(description)
        .replaceAll(RegExp('§.'), '')
        .replaceAll('\n', ' ')
        .trim();
  }

  static List<int> _encodeVarInt(int value) {
    var v = value & 0xFFFFFFFF;
    final out = <int>[];
    while (true) {
      if ((v & ~0x7F) == 0) {
        out.add(v);
        return out;
      }
      out.add((v & 0x7F) | 0x80);
      v >>= 7;
    }
  }

  /// Decodes a VarInt at [offset]; returns null if the bytes are incomplete.
  static ({int value, int next})? _decodeVarInt(List<int> data, int offset) {
    var value = 0;
    var position = 0;
    var index = offset;
    while (true) {
      if (index >= data.length) return null;
      final byte = data[index++];
      value |= (byte & 0x7F) << position;
      if ((byte & 0x80) == 0) return (value: value, next: index);
      position += 7;
      if (position >= 32) return null; // malformed
    }
  }

  // ---------------------------------------------------------------------------
  // Bedrock Edition: RakNet unconnected ping (single UDP datagram).
  // 0x01 | uint64 time | 16-byte magic | uint64 client GUID ->
  // 0x1C | uint64 time | uint64 server GUID | magic | uint16 len |
  // "Edition;MOTD;protocol;version;online;max;serverId;subMotd;gamemode;..."
  // ---------------------------------------------------------------------------

  static const List<int> _raknetMagic = [
    0x00, 0xff, 0xff, 0x00, 0xfe, 0xfe, 0xfe, 0xfe, //
    0xfd, 0xfd, 0xfd, 0xfd, 0x12, 0x34, 0x56, 0x78,
  ];

  static Future<ServerStatus> _pingBedrock(String host, int port) async {
    final addresses = await InternetAddress.lookup(host)
        .timeout(_pingTimeout);
    final address = addresses.firstWhere(
      (a) => a.type == InternetAddressType.IPv4,
      orElse: () => addresses.first,
    );

    final stopwatch = Stopwatch()..start();
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    final completer = Completer<ServerStatus>();
    late final Timer timer;

    void finish(ServerStatus? status, [Object? error]) {
      if (completer.isCompleted) return;
      timer.cancel();
      socket.close();
      if (status != null) {
        completer.complete(status);
      } else {
        completer.completeError(error ?? const SocketException('ping failed'));
      }
    }

    timer = Timer(_pingTimeout, () {
      finish(null, TimeoutException('Bedrock ping timed out'));
    });

    socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final datagram = socket.receive();
      if (datagram == null) return;
      final status =
          _parseBedrockPong(datagram.data, stopwatch.elapsedMilliseconds);
      if (status != null) finish(status);
    }, onError: (Object e) => finish(null, e));

    try {
      final packet = BytesBuilder(copy: false)..addByte(0x01);
      final time = DateTime.now().millisecondsSinceEpoch;
      for (var i = 7; i >= 0; i--) {
        packet.addByte((time >> (8 * i)) & 0xFF);
      }
      packet.add(_raknetMagic);
      final random = Random();
      for (var i = 0; i < 8; i++) {
        packet.addByte(random.nextInt(256));
      }
      socket.send(packet.takeBytes(), address, port);
    } catch (e) {
      finish(null, e);
    }

    return completer.future;
  }

  static ServerStatus? _parseBedrockPong(List<int> data, int latencyMs) {
    // 1 (id) + 8 (time) + 8 (server GUID) + 16 (magic) + 2 (string length).
    if (data.length < 35 || data[0] != 0x1C) return null;
    final length = (data[33] << 8) | data[34];
    if (data.length < 35 + length) return null;
    final fields = utf8
        .decode(data.sublist(35, 35 + length), allowMalformed: true)
        .split(';');
    if (fields.length < 6) return null;
    final motd = [
      fields[1],
      if (fields.length > 7 && fields[7].isNotEmpty) fields[7],
    ].join(' ');
    return ServerStatus(
      online: true,
      motd: motd.replaceAll(RegExp('§.'), '').trim(),
      version: fields[3],
      playersOnline: int.tryParse(fields[4]) ?? 0,
      playersMax: int.tryParse(fields[5]) ?? 0,
      latencyMs: latencyMs,
    );
  }

  // ---------------------------------------------------------------------------
  // Hosted fallback: api.mcstatus.io v2 (free, 5 req/s per IP, cached 1 min
  // upstream). Used only when the direct ping errors out.
  // ---------------------------------------------------------------------------

  static Future<ServerStatus> _fetchFromMcstatusIo(
    String host,
    int port,
    bool bedrock,
  ) async {
    final edition = bedrock ? 'bedrock' : 'java';
    final response = await http.get(
      Uri.parse('https://api.mcstatus.io/v2/status/$edition/$host:$port'),
      headers: const {'User-Agent': 'InZone-App (game hub server status)'},
    ).timeout(_pingTimeout);
    if (response.statusCode != 200) {
      throw HttpException('mcstatus.io ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('unexpected mcstatus.io payload');
    }
    if (decoded['online'] != true) {
      return const ServerStatus(online: false, source: 'mcstatus.io');
    }
    final players = decoded['players'];
    final version = decoded['version'];
    final motd = decoded['motd'];
    return ServerStatus(
      online: true,
      motd: motd is Map ? (motd['clean'] as String?) ?? '' : '',
      playersOnline: players is Map ? (players['online'] as num?)?.toInt() ?? 0 : 0,
      playersMax: players is Map ? (players['max'] as num?)?.toInt() ?? 0 : 0,
      version: version is Map
          ? (version['name_clean'] as String?) ??
              (version['name'] as String?) ??
              ''
          : '',
      source: 'mcstatus.io',
    );
  }
}
