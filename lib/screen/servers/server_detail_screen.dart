import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:inzone/data/hosted_server.dart';
import 'package:inzone/screen/servers/server_web_screen.dart';
import 'package:inzone/services/hosted_server_service.dart';
import 'package:inzone/services/server_ping_service.dart';

/// Detail page for a community-hosted server: live status, copyable address,
/// join actions (Bedrock deep link into Minecraft, Geyser crossplay
/// detection for Java servers) and the optional live-map companion webview.
class ServerDetailScreen extends StatefulWidget {
  final HostedServer server;
  const ServerDetailScreen({super.key, required this.server});

  @override
  State<ServerDetailScreen> createState() => _ServerDetailScreenState();
}

class _ServerDetailScreenState extends State<ServerDetailScreen> {
  Future<ServerStatus>? _statusFuture;
  Future<ServerStatus?>? _crossplayFuture;

  HostedServer get server => widget.server;

  @override
  void initState() {
    super.initState();
    if (server.isMinecraft) {
      _statusFuture = ServerPingService.fetchStatus(
        host: server.host,
        port: server.port,
        bedrock: server.gameType == ServerGameType.minecraftBedrock,
      );
    }
    if (server.gameType == ServerGameType.minecraftJava) {
      _crossplayFuture = ServerPingService.probeBedrockCrossplay(server.host);
    }
  }

  void _refreshStatus() {
    if (!server.isMinecraft) return;
    setState(() {
      _statusFuture = ServerPingService.fetchStatus(
        host: server.host,
        port: server.port,
        bedrock: server.gameType == ServerGameType.minecraftBedrock,
      );
    });
  }

  void _copyAddress() {
    Clipboard.setData(ClipboardData(text: server.address));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Server address copied')),
    );
  }

  Future<void> _launchMinecraft({required bool addToList, required int port}) async {
    // Bedrock deep links (documented by Microsoft):
    //   minecraft://?addExternalServer=Name|host:port  — adds to server list
    //   minecraft://connect?serverUrl=host&serverPort=port — joins directly
    // '|' is the Name/address separator, so it can't appear inside Name.
    final safeName = server.name.replaceAll('|', ' ');
    final uri = addToList
        ? Uri.parse(
            'minecraft://?addExternalServer='
            '${Uri.encodeComponent(safeName)}%7C${server.host}:$port',
          )
        : Uri.parse(
            'minecraft://connect?serverUrl=${server.host}&serverPort=$port',
          );
    var launched = false;
    try {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      launched = false;
    }
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Couldn\'t open Minecraft — make sure the Bedrock app is installed.',
          ),
        ),
      );
    }
  }

  void _openMap() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ServerWebScreen(
          title: '${server.name} — Live map',
          url: server.mapUrl,
        ),
      ),
    );
  }

  void _share() {
    SharePlus.instance.share(
      ShareParams(
        text: 'Join my ${server.gameLabel} server "${server.name}" at '
            '${server.address} — found on InZone!',
      ),
    );
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove server?'),
        content: Text(
          '"${server.name}" will be removed from the community directory. '
          'The server itself is not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await HostedServerService.deleteServer(server.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn\'t remove the server.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOwner =
        FirebaseAuth.instance.currentUser?.uid == server.uploaderId &&
            server.uploaderId.isNotEmpty;
    return Scaffold(
      backgroundColor: theme.canvasColor,
      appBar: AppBar(
        backgroundColor: theme.canvasColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          server.name,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.share_outlined), onPressed: _share),
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildHeaderCard(theme),
            const SizedBox(height: 12),
            if (server.isMinecraft) ...[
              _buildStatusCard(theme),
              const SizedBox(height: 12),
            ],
            _buildJoinCard(theme),
            if (server.mapUrl.isNotEmpty) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _openMap,
                icon: const Icon(Icons.map_outlined),
                label: const Text('Live world map'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            server.gameLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (server.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(server.description, style: theme.textTheme.bodyMedium),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  server.address,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 18),
                tooltip: 'Copy address',
                onPressed: _copyAddress,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(ThemeData theme) {
    return FutureBuilder<ServerStatus>(
      future: _statusFuture,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState != ConnectionState.done;
        final status = snapshot.data ?? ServerStatus.offline;
        final color = loading
            ? Colors.grey
            : (status.online ? const Color(0xFF34D399) : Colors.redAccent);
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      loading
                          ? 'Checking status…'
                          : (status.online ? 'Online' : 'Offline'),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: loading ? null : _refreshStatus,
                  ),
                ],
              ),
              if (!loading && status.online) ...[
                const SizedBox(height: 6),
                if (status.motd.isNotEmpty)
                  Text(status.motd, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 6),
                Text(
                  [
                    'Players ${status.playersOnline}/${status.playersMax}',
                    if (status.version.isNotEmpty) status.version,
                    if (status.latencyMs > 0) '${status.latencyMs} ms',
                  ].join('  ·  '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildJoinCard(ThemeData theme) {
    Widget bedrockButtons(int port) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: () => _launchMinecraft(addToList: false, port: port),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.sports_esports),
              label: const Text('Join in Minecraft'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _launchMinecraft(addToList: true, port: port),
              icon: const Icon(Icons.playlist_add),
              label: const Text('Add to my server list'),
            ),
          ],
        );

    Widget content;
    switch (server.gameType) {
      case ServerGameType.minecraftBedrock:
        content = bedrockButtons(server.port);
        break;
      case ServerGameType.minecraftJava:
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Java Edition can\'t be joined from a phone — copy the address '
              'and join from your computer.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _copyAddress,
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Copy address'),
            ),
            FutureBuilder<ServerStatus?>(
              future: _crossplayFuture,
              builder: (context, snapshot) {
                if (snapshot.data == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '✨ Crossplay detected — this server also accepts '
                        'Bedrock players, so you can join from this device:',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      bedrockButtons(ServerPingService.bedrockDefaultPort),
                    ],
                  ),
                );
              },
            ),
          ],
        );
        break;
      case ServerGameType.other:
        content = Text(
          'Open ${server.gameLabel} on your device or computer and connect '
          'to the address above.',
          style: theme.textTheme.bodyMedium,
        );
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How to join',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          content,
        ],
      ),
    );
  }
}
