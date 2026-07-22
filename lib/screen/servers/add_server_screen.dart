import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:inzone/data/hosted_server.dart';
import 'package:inzone/services/hosted_server_service.dart';
import 'package:inzone/services/server_ping_service.dart';

/// Form to register a hosted game server (e.g. one rented at BisectHosting)
/// in the community directory. Minecraft servers can be test-pinged before
/// submitting.
class AddServerScreen extends StatefulWidget {
  const AddServerScreen({super.key});

  @override
  State<AddServerScreen> createState() => _AddServerScreenState();
}

class _AddServerScreenState extends State<AddServerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _gameNameController = TextEditingController();
  final _hostController = TextEditingController();
  final _portController =
      TextEditingController(text: '${ServerPingService.bedrockDefaultPort}');
  final _descriptionController = TextEditingController();
  final _mapUrlController = TextEditingController();

  ServerGameType _gameType = ServerGameType.minecraftBedrock;
  bool _portEdited = false;
  bool _submitting = false;
  String _testResult = '';

  static final _hostPattern = RegExp(r'^[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?$');

  @override
  void dispose() {
    _nameController.dispose();
    _gameNameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _descriptionController.dispose();
    _mapUrlController.dispose();
    super.dispose();
  }

  void _onGameTypeChanged(ServerGameType? type) {
    if (type == null) return;
    setState(() {
      _gameType = type;
      // Track the game's default port until the user types their own.
      if (!_portEdited) {
        switch (type) {
          case ServerGameType.minecraftBedrock:
            _portController.text = '${ServerPingService.bedrockDefaultPort}';
            break;
          case ServerGameType.minecraftJava:
            _portController.text = '${ServerPingService.javaDefaultPort}';
            break;
          case ServerGameType.other:
            _portController.text = '';
            break;
        }
      }
    });
  }

  int? get _port => int.tryParse(_portController.text.trim());

  Future<void> _testConnection() async {
    final host = _hostController.text.trim();
    final port = _port;
    if (host.isEmpty || port == null) {
      setState(() => _testResult = 'Enter a host and port first.');
      return;
    }
    setState(() => _testResult = 'Testing…');
    final status = await ServerPingService.fetchStatus(
      host: host,
      port: port,
      bedrock: _gameType == ServerGameType.minecraftBedrock,
    );
    if (!mounted) return;
    setState(() {
      _testResult = status.online
          ? '✅ Online — ${status.playersOnline}/${status.playersMax} players'
              '${status.version.isNotEmpty ? ' · ${status.version}' : ''}'
          : '❌ No response. Check the address (the server may also just be '
              'offline right now).';
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to add a server.')),
      );
      return;
    }
    setState(() => _submitting = true);
    final server = HostedServer(
      id: '',
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      gameType: _gameType,
      gameName: _gameType == ServerGameType.other
          ? _gameNameController.text.trim()
          : '',
      host: _hostController.text.trim(),
      port: _port ?? 0,
      mapUrl: _mapUrlController.text.trim(),
      uploaderId: user.uid,
      createdAt: null,
    );
    try {
      await HostedServerService.addServer(server);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Couldn\'t add the server — please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMinecraft = _gameType != ServerGameType.other;
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
          'Add your server',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'List a server you host (BisectHosting or anywhere else) so '
                'the community can find and join it.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: _decoration('Server name *'),
                maxLength: 40,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<ServerGameType>(
                initialValue: _gameType,
                decoration: _decoration('Game *'),
                items: const [
                  DropdownMenuItem(
                    value: ServerGameType.minecraftBedrock,
                    child: Text('Minecraft: Bedrock (phones & consoles)'),
                  ),
                  DropdownMenuItem(
                    value: ServerGameType.minecraftJava,
                    child: Text('Minecraft: Java Edition'),
                  ),
                  DropdownMenuItem(
                    value: ServerGameType.other,
                    child: Text('Other game'),
                  ),
                ],
                onChanged: _onGameTypeChanged,
              ),
              if (_gameType == ServerGameType.other) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _gameNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: _decoration('Game name * (e.g. Palworld)'),
                  maxLength: 30,
                  validator: (v) => _gameType == ServerGameType.other &&
                          (v == null || v.trim().isEmpty)
                      ? 'Required'
                      : null,
                ),
              ],
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _hostController,
                      autocorrect: false,
                      enableSuggestions: false,
                      keyboardType: TextInputType.url,
                      decoration: _decoration('Host / IP *'),
                      validator: (v) {
                        final host = v?.trim() ?? '';
                        if (host.isEmpty) return 'Required';
                        if (!_hostPattern.hasMatch(host)) {
                          return 'Letters, digits, dots and dashes only';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _portController,
                      keyboardType: TextInputType.number,
                      decoration: _decoration('Port *'),
                      onChanged: (_) => _portEdited = true,
                      validator: (v) {
                        final port = int.tryParse(v?.trim() ?? '');
                        if (port == null || port < 1 || port > 65535) {
                          return '1–65535';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                decoration: _decoration('Description'),
                maxLength: 120,
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _mapUrlController,
                autocorrect: false,
                enableSuggestions: false,
                keyboardType: TextInputType.url,
                decoration: _decoration(
                  'Live map URL (BlueMap/Dynmap, optional)',
                ),
                validator: (v) {
                  final url = v?.trim() ?? '';
                  if (url.isEmpty) return null;
                  final parsed = Uri.tryParse(url);
                  if (parsed == null ||
                      !(parsed.isScheme('http') || parsed.isScheme('https'))) {
                    return 'Must start with http:// or https://';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              if (isMinecraft) ...[
                OutlinedButton.icon(
                  onPressed: _testConnection,
                  icon: const Icon(Icons.network_ping),
                  label: const Text('Test connection'),
                ),
                if (_testResult.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_testResult, style: theme.textTheme.bodyMedium),
                  ),
                const SizedBox(height: 8),
              ],
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(_submitting ? 'Adding…' : 'Add to directory'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        isDense: true,
      );
}
