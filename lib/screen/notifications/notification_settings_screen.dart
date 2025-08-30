import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:inzone/services/notification_service.dart';
import 'package:toasty_box/toast_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final user = FirebaseAuth.instance.currentUser;
  bool _isLoading = true;
  
  // Notification preferences
  bool _allEnabled = true;
  
  // Category preferences
  bool _dmEnabled = true;
  bool _dmSound = true;
  bool _groupEnabled = true;
  bool _groupMentionsOnly = false;
  int _groupBatchMins = 30;
  bool _engagementEnabled = true;
  int _engagementBatchMins = 60;
  bool _aiNudgesEnabled = true;
  int _aiNudgesMaxPerDay = 2;
  bool _systemEnabled = true;
  bool _rareOffersEnabled = true;
  int _rareOffersMaxPerWeek = 2;
  
  // Quiet hours
  TimeOfDay _quietHoursStart = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _quietHoursEnd = const TimeOfDay(hour: 8, minute: 0);

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    if (user == null) return;
    
    try {
      final prefs = await NotificationService.getNotificationPreferences();
      if (prefs != null) {
        setState(() {
          _allEnabled = prefs['allEnabled'] ?? true;
          
          final quietHours = prefs['quietHours'] ?? {};
          if (quietHours['start'] != null) {
            final start = quietHours['start'].split(':');
            _quietHoursStart = TimeOfDay(
              hour: int.parse(start[0]),
              minute: int.parse(start[1]),
            );
          }
          if (quietHours['end'] != null) {
            final end = quietHours['end'].split(':');
            _quietHoursEnd = TimeOfDay(
              hour: int.parse(end[0]),
              minute: int.parse(end[1]),
            );
          }
          
          final categories = prefs['categories'] ?? {};
          final dm = categories['dm'] ?? {};
          _dmEnabled = dm['enabled'] ?? true;
          _dmSound = dm['sound'] ?? true;
          
          final group = categories['group'] ?? {};
          _groupEnabled = group['enabled'] ?? true;
          _groupMentionsOnly = group['mentionsOnly'] ?? false;
          _groupBatchMins = group['batchMins'] ?? 30;
          
          final engagement = categories['engagement'] ?? {};
          _engagementEnabled = engagement['enabled'] ?? true;
          _engagementBatchMins = engagement['batchMins'] ?? 60;
          
          final aiNudges = categories['aiNudges'] ?? {};
          _aiNudgesEnabled = aiNudges['enabled'] ?? true;
          _aiNudgesMaxPerDay = aiNudges['maxPerDay'] ?? 2;
          
          _systemEnabled = categories['system']?['enabled'] ?? true;
          
          final rareOffers = categories['rareOffers'] ?? {};
          _rareOffersEnabled = rareOffers['enabled'] ?? true;
          _rareOffersMaxPerWeek = rareOffers['maxPerWeek'] ?? 2;
        });
      }
    } catch (e) {
      print('Error loading preferences: $e');
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _savePreferences() async {
    if (user == null) return;
    
    try {
      final prefs = {
        'allEnabled': _allEnabled,
        'quietHours': {
          'start': '${_quietHoursStart.hour.toString().padLeft(2, '0')}:${_quietHoursStart.minute.toString().padLeft(2, '0')}',
          'end': '${_quietHoursEnd.hour.toString().padLeft(2, '0')}:${_quietHoursEnd.minute.toString().padLeft(2, '0')}',
        },
        'categories': {
          'dm': {
            'enabled': _dmEnabled,
            'sound': _dmSound,
          },
          'group': {
            'enabled': _groupEnabled,
            'mentionsOnly': _groupMentionsOnly,
            'batchMins': _groupBatchMins,
          },
          'engagement': {
            'enabled': _engagementEnabled,
            'batchMins': _engagementBatchMins,
          },
          'aiNudges': {
            'enabled': _aiNudgesEnabled,
            'maxPerDay': _aiNudgesMaxPerDay,
          },
          'system': {
            'enabled': _systemEnabled,
          },
          'rareOffers': {
            'enabled': _rareOffersEnabled,
            'maxPerWeek': _rareOffersMaxPerWeek,
          },
        },
      };
      
      await NotificationService.updateNotificationPreferences(prefs);
      
      if (mounted) {
        ToastService.showToast(
          context,
          backgroundColor: Theme.of(context).canvasColor,
          shadowColor: Colors.transparent,
          leading: const Icon(
            FeatherIcons.checkCircle,
            color: Colors.greenAccent,
          ),
          message: 'Notification preferences saved',
        );
      }
    } catch (e) {
      if (mounted) {
        ToastService.showToast(
          context,
          backgroundColor: Theme.of(context).canvasColor,
          shadowColor: Colors.transparent,
          leading: const Icon(
            FeatherIcons.xCircle,
            color: Colors.redAccent,
          ),
          message: 'Error saving preferences: $e',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notification Settings')),
        body: const Center(child: Text('Please log in to manage notification settings')),
      );
    }

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notification Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Notification Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _savePreferences,
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildMasterToggle(),
          const SizedBox(height: 24),
          _buildQuietHoursSection(),
          const SizedBox(height: 24),
          _buildCategorySection(),
        ],
      ),
    );
  }

  Widget _buildMasterToggle() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              FeatherIcons.bell,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'All Notifications',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Enable or disable all notifications',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: _allEnabled,
              onChanged: (value) {
                setState(() => _allEnabled = value);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuietHoursSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  FeatherIcons.moon,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 16),
                Text(
                  'Quiet Hours',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'During quiet hours, notifications will be queued and delivered as a morning digest',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTimeSelector(
                    'Start',
                    _quietHoursStart,
                    (time) => setState(() => _quietHoursStart = time),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTimeSelector(
                    'End',
                    _quietHoursEnd,
                    (time) => setState(() => _quietHoursEnd = time),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSelector(String label, TimeOfDay time, Function(TimeOfDay) onChanged) {
    return InkWell(
      onTap: () async {
        final newTime = await showTimePicker(
          context: context,
          initialTime: time,
        );
        if (newTime != null) {
          onChanged(newTime);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              time.format(context),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Categories',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildCategoryCard(
          icon: FeatherIcons.messageCircle,
          title: 'Direct Messages',
          subtitle: 'AI and human 1:1 conversations',
          enabled: _dmEnabled,
          onToggle: (value) => setState(() => _dmEnabled = value),
          children: [
            _buildSwitchTile(
              'Sound',
              'Play sound for new messages',
              _dmSound,
              (value) => setState(() => _dmSound = value),
            ),
          ],
        ),
        _buildCategoryCard(
          icon: FeatherIcons.users,
          title: 'Group Chats',
          subtitle: 'Messages in group conversations',
          enabled: _groupEnabled,
          onToggle: (value) => setState(() => _groupEnabled = value),
          children: [
            _buildSwitchTile(
              'Mentions Only',
              'Only notify when mentioned',
              _groupMentionsOnly,
              (value) => setState(() => _groupMentionsOnly = value),
            ),
            _buildSliderTile(
              'Batch Time',
              'Group messages for $_groupBatchMins minutes',
              _groupBatchMins.toDouble(),
              15,
              120,
              (value) => setState(() => _groupBatchMins = value.round()),
            ),
          ],
        ),
        _buildCategoryCard(
          icon: FeatherIcons.heart,
          title: 'Post Engagement',
          subtitle: 'Likes, comments, and reactions',
          enabled: _engagementEnabled,
          onToggle: (value) => setState(() => _engagementEnabled = value),
          children: [
            _buildSliderTile(
              'Batch Time',
              'Group engagement for $_engagementBatchMins minutes',
              _engagementBatchMins.toDouble(),
              30,
              180,
              (value) => setState(() => _engagementBatchMins = value.round()),
            ),
          ],
        ),
  // Temporarily hide AI Nudges controls from the UI while the
  // nudges feature is being reworked. Keep the code here (commented)
  // so the settings can be restored later if needed.
  // _buildCategoryCard(
  //   icon: FeatherIcons.zap,
  //   title: 'AI Nudges',
  //   subtitle: 'Duolingo-style conversation prompts',
  //   enabled: _aiNudgesEnabled,
  //   onToggle: (value) => setState(() => _aiNudgesEnabled = value),
  //   children: [
  //     _buildSliderTile(
  //       'Max Per Day',
  //       'Up to $_aiNudgesMaxPerDay nudges per day',
  //       _aiNudgesMaxPerDay.toDouble(),
  //       1,
  //       5,
  //       (value) => setState(() => _aiNudgesMaxPerDay = value.round()),
  //     ),
  //   ],
  // ),
        _buildCategoryCard(
          icon: FeatherIcons.gift,
          title: 'Coin Offers',
          subtitle: 'Special offers to earn InCash',
          enabled: _rareOffersEnabled,
          onToggle: (value) => setState(() => _rareOffersEnabled = value),
          children: [
            _buildSliderTile(
              'Max Per Week',
              'Up to $_rareOffersMaxPerWeek offers per week',
              _rareOffersMaxPerWeek.toDouble(),
              1,
              5,
              (value) => setState(() => _rareOffersMaxPerWeek = value.round()),
            ),
          ],
        ),
        _buildCategoryCard(
          icon: FeatherIcons.bell,
          title: 'System',
          subtitle: 'Streaks, milestones, and alerts',
          enabled: _systemEnabled,
          onToggle: (value) => setState(() => _systemEnabled = value),
        ),
      ],
    );
  }

  Widget _buildCategoryCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool enabled,
    required Function(bool) onToggle,
    List<Widget>? children,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: enabled,
                  onChanged: onToggle,
                ),
              ],
            ),
            if (children != null && enabled) ...[
              const SizedBox(height: 16),
              ...children,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool value, Function(bool) onChanged) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildSliderTile(String title, String subtitle, double value, double min, double max, Function(double) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: (max - min).round(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
