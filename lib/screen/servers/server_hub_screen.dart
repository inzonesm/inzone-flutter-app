import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:inzone/data/hosted_server.dart';
import 'package:inzone/screen/servers/add_server_screen.dart';
import 'package:inzone/screen/servers/server_detail_screen.dart';
import 'package:inzone/screen/servers/server_web_screen.dart';
import 'package:inzone/services/bisect_hosting_service.dart';
import 'package:inzone/services/hosted_server_service.dart';
import 'package:inzone/services/server_ping_service.dart';

/// Multiplayer Server Hub — the BisectHosting integration surface:
///  - Servers: community directory of hosted game servers with live status,
///    tap-to-join for Minecraft Bedrock, live-map companions;
///  - My Hosting: the user's own BisectHosting servers via the Starbase panel
///    Client API (paste-your-own `ptlc_` key) with power controls;
///  - Host a Game: catalog of hostable games deep-linking into
///    BisectHosting's order flow.
class ServerHubScreen extends StatelessWidget {
  const ServerHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: theme.canvasColor,
        appBar: AppBar(
          backgroundColor: theme.canvasColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(
            'Server Hub',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          bottom: TabBar(
            labelColor: theme.textTheme.bodyLarge?.color,
            unselectedLabelColor: theme.textTheme.bodyMedium?.color,
            indicatorColor: theme.colorScheme.primary,
            tabs: const [
              Tab(text: 'Servers'),
              Tab(text: 'My Hosting'),
              Tab(text: 'Host a Game'),
            ],
          ),
        ),
        body: const SafeArea(
          child: TabBarView(
            children: [
              _CommunityServersTab(),
              _BisectAccountTab(),
              _HostGameTab(),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Tab 1: community server directory.
// -----------------------------------------------------------------------------

class _CommunityServersTab extends StatefulWidget {
  const _CommunityServersTab();

  @override
  State<_CommunityServersTab> createState() => _CommunityServersTabState();
}

class _CommunityServersTabState extends State<_CommunityServersTab>
    with AutomaticKeepAliveClientMixin {
  late Future<List<HostedServer>> _serversFuture;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _serversFuture = HostedServerService.fetchAll();
  }

  Future<void> _reload() async {
    setState(() => _serversFuture = HostedServerService.fetchAll());
    await _serversFuture;
  }

  Future<void> _openAddServer() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddServerScreen()),
    );
    if (added == true && mounted) _reload();
  }

  Future<void> _openDetail(HostedServer server) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ServerDetailScreen(server: server)),
    );
    if (changed == true && mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.canvasColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddServer,
        backgroundColor: theme.colorScheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Add server',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: FutureBuilder<List<HostedServer>>(
        future: _serversFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Center(
              child: CircularProgressIndicator(
                color: theme.textTheme.bodyLarge?.color,
              ),
            );
          }
          final servers = snapshot.data ?? const <HostedServer>[];
          if (snapshot.hasError || servers.isEmpty) {
            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 96),
                  Icon(
                    Icons.dns_outlined,
                    size: 44,
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    snapshot.hasError
                        ? 'Couldn\'t load servers. Pull to retry.'
                        : 'No community servers yet.\nHost one and add it here!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.textTheme.bodyMedium?.color),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              itemCount: servers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, index) {
                final server = servers[index];
                return _ServerTile(
                  server: server,
                  onTap: () => _openDetail(server),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _ServerTile extends StatelessWidget {
  final HostedServer server;
  final VoidCallback onTap;
  const _ServerTile({required this.server, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
              child: Text(
                server.gameType == ServerGameType.other ? '🎮' : '⛏️',
                style: const TextStyle(fontSize: 20),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    server.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${server.gameLabel} · ${server.address}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _ServerStatusBadge(server: server),
          ],
        ),
      ),
    );
  }
}

/// Compact online/offline pill fed by ServerPingService (60s TTL cache).
/// Non-Minecraft servers have no in-app ping protocol, so no badge is shown.
class _ServerStatusBadge extends StatelessWidget {
  final HostedServer server;
  const _ServerStatusBadge({required this.server});

  @override
  Widget build(BuildContext context) {
    if (!server.isMinecraft) return const SizedBox.shrink();
    return FutureBuilder<ServerStatus>(
      future: ServerPingService.fetchStatus(
        host: server.host,
        port: server.port,
        bedrock: server.gameType == ServerGameType.minecraftBedrock,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final status = snapshot.data!;
        final color = status.online ? const Color(0xFF34D399) : Colors.redAccent;
        final label = status.online
            ? '${status.playersOnline}/${status.playersMax}'
            : 'Offline';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// Tab 2: the user's own BisectHosting account (Starbase panel Client API).
// -----------------------------------------------------------------------------

class _BisectAccountTab extends StatefulWidget {
  const _BisectAccountTab();

  @override
  State<_BisectAccountTab> createState() => _BisectAccountTabState();
}

class _BisectAccountTabState extends State<_BisectAccountTab>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _keyController = TextEditingController();
  String? _apiKey;
  bool _restoringKey = true;
  bool _connecting = false;
  Future<List<BisectServer>>? _serversFuture;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _restoreKey();
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _restoreKey() async {
    final key = await BisectHostingService.getApiKey();
    if (!mounted) return;
    setState(() {
      _apiKey = key;
      _restoringKey = false;
      if (key != null) {
        _serversFuture = BisectHostingService.listServers(key);
      }
    });
  }

  Future<void> _connect() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) return;
    setState(() => _connecting = true);
    try {
      // Validate the key by listing servers before persisting it.
      final servers = await BisectHostingService.listServers(key);
      await BisectHostingService.setApiKey(key);
      if (!mounted) return;
      setState(() {
        _apiKey = key;
        _serversFuture = Future.value(servers);
        _connecting = false;
      });
      _keyController.clear();
    } catch (e) {
      if (!mounted) return;
      setState(() => _connecting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is BisectAuthException
                ? e.message
                : 'Couldn\'t reach BisectHosting. Check your connection and try again.',
          ),
        ),
      );
    }
  }

  Future<void> _disconnect() async {
    await BisectHostingService.clearApiKey();
    if (!mounted) return;
    setState(() {
      _apiKey = null;
      _serversFuture = null;
    });
  }

  void _refreshServers() {
    final key = _apiKey;
    if (key == null) return;
    setState(() => _serversFuture = BisectHostingService.listServers(key));
  }

  void _openPanel() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ServerWebScreen(
          title: 'BisectHosting Panel',
          url: BisectHostingService.panelBaseUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    if (_restoringKey) {
      return Center(
        child: CircularProgressIndicator(
          color: theme.textTheme.bodyLarge?.color,
        ),
      );
    }
    return _apiKey == null ? _buildConnectCard(theme) : _buildServerList(theme);
  }

  Widget _buildConnectCard(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Manage your BisectHosting servers',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Already hosting with BisectHosting? Connect your account to '
                'see server status and start, stop or restart your servers '
                'right from InZone.\n\n'
                '1. Log in at ${BisectHostingService.panelApiCredentialsHint}\n'
                '2. Create an API key\n'
                '3. Paste it below — it stays on this device only.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _keyController,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  hintText: 'ptlc_…',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _connecting ? null : _connect,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(_connecting ? 'Connecting…' : 'Connect account'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _openPanel,
          icon: const Icon(Icons.language),
          label: const Text('Open BisectHosting panel'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => DefaultTabController.of(context).animateTo(2),
          icon: const Icon(Icons.add_business_outlined),
          label: const Text('Don\'t have a server? Host one'),
        ),
      ],
    );
  }

  Widget _buildServerList(ThemeData theme) {
    return FutureBuilder<List<BisectServer>>(
      future: _serversFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Center(
            child: CircularProgressIndicator(
              color: theme.textTheme.bodyLarge?.color,
            ),
          );
        }
        final authFailed = snapshot.error is BisectAuthException;
        final servers = snapshot.data ?? const <BisectServer>[];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Your servers',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _refreshServers,
                ),
                TextButton(
                  onPressed: _disconnect,
                  child: const Text('Disconnect'),
                ),
              ],
            ),
            if (snapshot.hasError)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  authFailed
                      ? 'Your API key was rejected — it may have been revoked. '
                          'Disconnect and paste a fresh one.'
                      : 'Couldn\'t load your servers. Tap refresh to retry.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.textTheme.bodyMedium?.color),
                ),
              )
            else if (servers.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No servers on this account yet.\n'
                  'Order one in the "Host a Game" tab!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.textTheme.bodyMedium?.color),
                ),
              )
            else
              for (final server in servers) ...[
                _BisectServerCard(apiKey: _apiKey!, server: server),
                const SizedBox(height: 10),
              ],
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _openPanel,
              icon: const Icon(Icons.language),
              label: const Text('Full panel (console, files, backups)'),
            ),
          ],
        );
      },
    );
  }
}

class _BisectServerCard extends StatefulWidget {
  final String apiKey;
  final BisectServer server;
  const _BisectServerCard({required this.apiKey, required this.server});

  @override
  State<_BisectServerCard> createState() => _BisectServerCardState();
}

class _BisectServerCardState extends State<_BisectServerCard> {
  late Future<BisectServerResources> _resourcesFuture;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _resourcesFuture = BisectHostingService.fetchResources(
      widget.apiKey,
      widget.server.identifier,
    );
  }

  Future<void> _power(String signal) async {
    if (signal != 'start') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('${signal == 'stop' ? 'Stop' : 'Restart'} server?'),
          content: Text(
            'Players currently online on "${widget.server.name}" will be '
            'disconnected.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(signal == 'stop' ? 'Stop' : 'Restart'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await BisectHostingService.sendPowerSignal(
        widget.apiKey,
        widget.server.identifier,
        signal,
      );
      // Give the panel a moment to reflect the new state before re-reading.
      await Future.delayed(const Duration(seconds: 2));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Power action failed — try the panel.')),
        );
      }
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _resourcesFuture = BisectHostingService.fetchResources(
        widget.apiKey,
        widget.server.identifier,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.server.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              FutureBuilder<BisectServerResources>(
                future: _resourcesFuture,
                builder: (context, snapshot) {
                  final state = snapshot.data?.state;
                  final running = state == 'running';
                  final color = running
                      ? const Color(0xFF34D399)
                      : (state == null ? Colors.grey : Colors.orangeAccent);
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      state ?? '…',
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          if (widget.server.address != null) ...[
            const SizedBox(height: 4),
            Text(
              widget.server.address!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.textTheme.bodyMedium?.color,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              _powerButton(Icons.play_arrow, 'Start', () => _power('start')),
              _powerButton(Icons.restart_alt, 'Restart', () => _power('restart')),
              _powerButton(Icons.stop, 'Stop', () => _power('stop')),
              if (_busy) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _powerButton(IconData icon, String tooltip, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      onPressed: _busy ? null : onPressed,
      visualDensity: VisualDensity.compact,
    );
  }
}

// -----------------------------------------------------------------------------
// Tab 3: "host a game" order catalog.
// -----------------------------------------------------------------------------

class _HostGameTab extends StatelessWidget {
  const _HostGameTab();

  Future<void> _openOrder(BuildContext context, Uri uri) async {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn\'t open the browser.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const entries = BisectHostingService.catalog;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: entries.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Host your own game server',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Rent a server for any of these games at BisectHosting, '
                    'then add it to the Servers tab so the community can join. '
                    'Ordering opens in your browser.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          );
        }
        if (index == entries.length + 1) {
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton.icon(
              onPressed: () =>
                  _openOrder(context, BisectHostingService.allGamesUri),
              icon: const Icon(Icons.grid_view),
              label: const Text('Browse all 100+ games'),
            ),
          );
        }
        final entry = entries[index - 1];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: () => _openOrder(context, BisectHostingService.orderUri(entry)),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Text(entry.emoji, style: const TextStyle(fontSize: 26)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          entry.blurb,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodyMedium?.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.open_in_new,
                    size: 18,
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
