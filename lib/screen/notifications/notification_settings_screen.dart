import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:inzone/services/notification_service.dart';
import 'package:toasty_box/toast_service.dart';
import 'dart:async';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final user = FirebaseAuth.instance.currentUser;
  bool _isLoading = true;
  Timer? _debounceTimer;
  bool _isSaving = false;
  
  // Master controls
  bool _pauseAll = false;
  
  // Store actual toggle states (preserved when pauseAll is on)
  bool _actualLikesEnabled = true;
  bool _actualCommentsEnabled = true;
  bool _actualDmEnabled = true;
  bool _actualGroupEnabled = true;
  bool _actualFollowersEnabled = true;
  bool _actualSystemEnabled = true;
  bool _actualRareOffersEnabled = true;
  
  // Likes settings (includes comment likes)
  bool _likesEnabled = true;
  String _likesFrom = 'everyone'; // 'everyone', 'following', 'off'
  
  // Comments settings
  bool _commentsEnabled = true;
  String _commentsFrom = 'everyone'; // 'everyone', 'following', 'followingAndFollowers', 'off'
  
  // DMs settings
  bool _dmEnabled = true;
  String _dmFrom = 'everyone'; // 'everyone', 'following', 'off'
  bool _dmSound = true;
  bool _dmShowPreviews = true;
  
  // Group chat settings
  bool _groupEnabled = true;
  String _groupNotifyFor = 'everyone'; // 'everyone', 'mentions', 'popularCharacters', 'mentionsAndCharacters', 'off'
  int _groupBatchMins = 15;
  
  // Followers settings
  bool _followersEnabled = true;
  
  // Reminders and AI settings - TEMPORARILY DISABLED (feature being reworked)
  // bool _aiNudgesEnabled = false; // Off by default as feature is being reworked
  // int _aiNudgesMaxPerDay = 2;
  
  // Other activity
  bool _rareOffersEnabled = true;
  int _rareOffersMaxPerWeek = 2;
  bool _systemEnabled = true;
  
  // Quiet hours
  bool _quietHoursEnabled = false;
  TimeOfDay _quietHoursStart = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _quietHoursEnd = const TimeOfDay(hour: 8, minute: 0);

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    if (user == null) return;
    
    try {
      final prefs = await NotificationService.getNotificationPreferences();
      if (prefs != null) {
        setState(() {
          _pauseAll = prefs['pauseAll'] ?? false;
          
          // Quiet hours
          _quietHoursEnabled = prefs['quietHoursEnabled'] ?? false;
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
          
          // Likes (includes comment likes)
          final likes = categories['likes'] ?? {};
          _likesEnabled = likes['enabled'] ?? true;
          _likesFrom = likes['from'] ?? 'everyone';
          
          // Comments
          final comments = categories['comments'] ?? {};
          _commentsEnabled = comments['enabled'] ?? true;
          _commentsFrom = comments['from'] ?? 'everyone';
          
          // DMs
          final dm = categories['dm'] ?? {};
          _dmEnabled = dm['enabled'] ?? true;
          _dmFrom = dm['from'] ?? 'everyone';
          _dmSound = dm['sound'] ?? true;
          _dmShowPreviews = dm['showPreviews'] ?? true;
          
          // Group chats
          final group = categories['group'] ?? {};
          _groupEnabled = group['enabled'] ?? true;
          _groupNotifyFor = group['notifyFor'] ?? 'everyone';
          _groupBatchMins = group['batchMins'] ?? 15;
          
          // Followers
          _followersEnabled = categories['followers']?['enabled'] ?? true;
          
          // AI nudges - TEMPORARILY DISABLED
          // final aiNudges = categories['aiNudges'] ?? {};
          // _aiNudgesEnabled = aiNudges['enabled'] ?? false;
          // _aiNudgesMaxPerDay = aiNudges['maxPerDay'] ?? 2;
          
          // System & Offers
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

  void _autoSave() {
    // Cancel existing timer
    _debounceTimer?.cancel();
    
    // Start new timer - save after 1 second of no changes
    _debounceTimer = Timer(const Duration(milliseconds: 1000), () {
      _savePreferences();
    });
  }

  Future<void> _savePreferences() async {
    if (user == null || _isSaving) return;
    
    setState(() => _isSaving = true);
    print('💾 Auto-saving preferences...');
    
    try {
      // Get timezone offset in hours (e.g., -5 for EST/UTC-5)
      final timezoneOffsetHours = DateTime.now().timeZoneOffset.inHours;
      
      final prefs = {
        'pauseAll': _pauseAll,
        'quietHoursEnabled': _quietHoursEnabled,
        'quietHours': {
          'start': '${_quietHoursStart.hour.toString().padLeft(2, '0')}:${_quietHoursStart.minute.toString().padLeft(2, '0')}',
          'end': '${_quietHoursEnd.hour.toString().padLeft(2, '0')}:${_quietHoursEnd.minute.toString().padLeft(2, '0')}',
        },
        'timezoneOffset': timezoneOffsetHours,  // Add timezone offset
        'categories': {
          'likes': {
            'enabled': _likesEnabled,
            'from': _likesFrom,
          },
          'comments': {
            'enabled': _commentsEnabled,
            'from': _commentsFrom,
          },
          // Comment likes now use the same settings as regular likes
          'commentLikes': {
            'enabled': _likesEnabled,
            'from': _likesFrom,
          },
          'dm': {
            'enabled': _dmEnabled,
            'from': _dmFrom,
            'sound': _dmSound,
            'showPreviews': _dmShowPreviews,
          },
          'group': {
            'enabled': _groupEnabled,
            'notifyFor': _groupNotifyFor,
            'batchMins': _groupBatchMins,
          },
          'followers': {
            'enabled': _followersEnabled,
          },
          // AI nudges - TEMPORARILY DISABLED
          // 'aiNudges': {
          //   'enabled': _aiNudgesEnabled,
          //   'maxPerDay': _aiNudgesMaxPerDay,
          // },
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
      print('✅ Preferences auto-saved');
    } catch (e) {
      print('❌ Error auto-saving preferences: $e');
      if (mounted) {
        ToastService.showToast(
          context,
          backgroundColor: Theme.of(context).canvasColor,
          shadowColor: Colors.transparent,
          leading: const Icon(
            FeatherIcons.xCircle,
            color: Colors.redAccent,
          ),
          message: 'Error saving: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
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
        title: Row(
          children: [
            const Text('Push Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
            if (_isSaving) ...[  
              const SizedBox(width: 12),
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildMasterToggle(),
          const SizedBox(height: 24),
          _buildQuietHoursSection(),
          const SizedBox(height: 24),
          _buildSectionHeader('Posts, Stories and Comments'),
          _buildLikesSection(),
          _buildCommentsSection(),
          const SizedBox(height: 24),
          _buildSectionHeader('Following and Followers'),
          _buildFollowersSection(),
          const SizedBox(height: 24),
          _buildSectionHeader('Direct Messages'),
          _buildDMSection(),
          const SizedBox(height: 24),
          _buildSectionHeader('Group Chats'),
          _buildGroupChatsSection(),
          const SizedBox(height: 24),
          _buildSectionHeader('Other Activity'),
          _buildRareOffersSection(),
          _buildSystemSection(),
          // Temporarily hidden - feature being reworked
          // const SizedBox(height: 24),
          // _buildSectionHeader('Reminders'),
          // _buildAINudgesSection(),
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
              _pauseAll ? FeatherIcons.bellOff : FeatherIcons.bell,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pause All',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Temporarily pause all push notifications',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: _pauseAll,
              onChanged: (value) {
                setState(() {
                  if (value) {
                    // Save actual states and turn all toggles off
                    _actualLikesEnabled = _likesEnabled;
                    _actualCommentsEnabled = _commentsEnabled;
                    _actualDmEnabled = _dmEnabled;
                    _actualGroupEnabled = _groupEnabled;
                    _actualFollowersEnabled = _followersEnabled;
                    _actualSystemEnabled = _systemEnabled;
                    _actualRareOffersEnabled = _rareOffersEnabled;
                    
                    // Turn all toggles OFF visually
                    _likesEnabled = false;
                    _commentsEnabled = false;
                    _dmEnabled = false;
                    _groupEnabled = false;
                    _followersEnabled = false;
                    _systemEnabled = false;
                    _rareOffersEnabled = false;
                  } else {
                    // Restore actual states
                    _likesEnabled = _actualLikesEnabled;
                    _commentsEnabled = _actualCommentsEnabled;
                    _dmEnabled = _actualDmEnabled;
                    _groupEnabled = _actualGroupEnabled;
                    _followersEnabled = _actualFollowersEnabled;
                    _systemEnabled = _actualSystemEnabled;
                    _rareOffersEnabled = _actualRareOffersEnabled;
                  }
                  _pauseAll = value;
                });
                _autoSave();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
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
                Expanded(
                  child: Text(
                    'Quiet Hours',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Switch(
                  value: _quietHoursEnabled,
                  onChanged: (value) {
                    setState(() => _quietHoursEnabled = value);
                    _autoSave();
                  },
                ),
              ],
            ),
            if (_quietHoursEnabled) ...[
              const SizedBox(height: 8),
              Text(
                'Notifications will be queued and delivered as a morning digest',
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
          _autoSave();
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

  Widget _buildLikesSection() {
    return _buildOptionCard(
      title: 'Likes (Posts & Comments)',
      enabled: _likesEnabled,
      onToggle: (value) {
        setState(() {
          _likesEnabled = value;
          _actualLikesEnabled = value; // Also update actual state
          // When re-enabling, reset to 'everyone' if currently 'off'
          if (value && _likesFrom == 'off') {
            _likesFrom = 'everyone';
          }
        });
        _autoSave();
      },
      selectedOption: _likesFrom,
      options: const {
        'everyone': 'From Everyone',
        'following': 'From People I Follow',
        'off': 'Off',
      },
      onOptionChanged: (value) {
        setState(() {
          _likesFrom = value;
          // Auto-disable toggle when 'off' is selected
          if (value == 'off') {
            _likesEnabled = false;
          }
        });
        _autoSave();
      },
    );
  }

  Widget _buildCommentsSection() {
    return _buildOptionCard(
      title: 'Comments',
      enabled: _commentsEnabled,
      onToggle: (value) {
        setState(() {
          _commentsEnabled = value;
          _actualCommentsEnabled = value; // Also update actual state
          // When re-enabling, reset to 'everyone' if currently 'off'
          if (value && _commentsFrom == 'off') {
            _commentsFrom = 'everyone';
          }
        });
        _autoSave();
      },
      selectedOption: _commentsFrom,
      options: const {
        'everyone': 'From Everyone',
        'following': 'From People I Follow',
        'followingAndFollowers': 'From People I Follow and My Followers',
        'off': 'Off',
      },
      onOptionChanged: (value) {
        setState(() {
          _commentsFrom = value;
          // Auto-disable toggle when 'off' is selected
          if (value == 'off') {
            _commentsEnabled = false;
          }
        });
        _autoSave();
      },
    );
  }

  Widget _buildFollowersSection() {
    return _buildSimpleToggleCard(
      title: 'Followers',
      subtitle: 'Get notified when someone follows you',
      enabled: _followersEnabled,
      onToggle: (value) {
        setState(() {
          _followersEnabled = value;
          _actualFollowersEnabled = value; // Also update actual state
        });
        _autoSave();
      },
    );
  }

  Widget _buildDMSection() {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Message Requests',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Switch(
                  value: _dmEnabled,
                  onChanged: (value) {
                    setState(() {
                      _dmEnabled = value;
                      _actualDmEnabled = value; // Also update actual state
                      // When re-enabling, reset to 'everyone' if currently 'off'
                      if (value && _dmFrom == 'off') {
                        _dmFrom = 'everyone';
                      }
                    });
                    _autoSave();
                  },
                ),
              ],
            ),
            if (_dmEnabled) ...[
              const SizedBox(height: 16),
              _buildRadioOption(
                'From Everyone',
                _dmFrom == 'everyone',
                () {
                  setState(() => _dmFrom = 'everyone');
                  _autoSave();
                },
              ),
              _buildRadioOption(
                'From People I Follow',
                _dmFrom == 'following',
                () {
                  setState(() => _dmFrom = 'following');
                  _autoSave();
                },
              ),
              _buildRadioOption(
                'Off',
                _dmFrom == 'off',
                () {
                  setState(() {
                    _dmFrom = 'off';
                    // Auto-disable toggle when 'off' is selected
                    _dmEnabled = false;
                  });
                  _autoSave();
                },
              ),
              const Divider(height: 32),
              _buildSwitchTile(
                'Sound',
                'Play sound for new messages',
                _dmSound,
                (value) {
                  setState(() => _dmSound = value);
                  _autoSave();
                },
              ),
              const SizedBox(height: 8),
              _buildSwitchTile(
                'Show Previews',
                'Display message content in notifications',
                _dmShowPreviews,
                (value) {
                  setState(() => _dmShowPreviews = value);
                  _autoSave();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGroupChatsSection() {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Group Chats',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Switch(
                  value: _groupEnabled,
                  onChanged: (value) {
                    setState(() {
                      _groupEnabled = value;
                      _actualGroupEnabled = value; // Also update actual state
                    });
                    _autoSave();
                  },
                ),
              ],
            ),
            if (_groupEnabled) ...[
              const SizedBox(height: 16),
              Text(
                'Get notifications for:',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 8),
              _buildRadioOption(
                'All Messages',
                _groupNotifyFor == 'everyone',
                () {
                  setState(() => _groupNotifyFor = 'everyone');
                  _autoSave();
                },
              ),
              _buildRadioOption(
                'Mentions Only',
                _groupNotifyFor == 'mentions',
                () {
                  setState(() => _groupNotifyFor = 'mentions');
                  _autoSave();
                },
              ),
              _buildRadioOption(
                'AI Characters Only',
                _groupNotifyFor == 'popularCharacters',
                () {
                  setState(() => _groupNotifyFor = 'popularCharacters');
                  _autoSave();
                },
              ),
              _buildRadioOption(
                'Mentions & AI Characters',
                _groupNotifyFor == 'mentionsAndCharacters',
                () {
                  setState(() => _groupNotifyFor = 'mentionsAndCharacters');
                  _autoSave();
                },
              ),
              _buildRadioOption(
                'Off',
                _groupNotifyFor == 'off',
                () {
                  setState(() => _groupNotifyFor = 'off');
                  _autoSave();
                },
              ),
              const Divider(height: 32),
              _buildSliderTile(
                'Batch Messages',
                'Group notifications every $_groupBatchMins minutes',
                _groupBatchMins.toDouble(),
                5,
                60,
                (value) {
                  setState(() => _groupBatchMins = value.round());
                  _autoSave();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRareOffersSection() {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(FeatherIcons.gift, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Coin Offers',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Special offers to earn InCash',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _rareOffersEnabled,
                  onChanged: (value) {
                    setState(() {
                      _rareOffersEnabled = value;
                      _actualRareOffersEnabled = value; // Also update actual state
                    });
                    _autoSave();
                  },
                ),
              ],
            ),
            if (_rareOffersEnabled) ...[
              const SizedBox(height: 16),
              _buildSliderTile(
                'Max Per Week',
                'Up to $_rareOffersMaxPerWeek offers per week',
                _rareOffersMaxPerWeek.toDouble(),
                1,
                5,
                (value) {
                  setState(() => _rareOffersMaxPerWeek = value.round());
                  _autoSave();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSystemSection() {
    return _buildSimpleToggleCard(
      icon: FeatherIcons.bell,
      title: 'System Notifications',
      subtitle: 'Streaks, milestones, and alerts',
      enabled: _systemEnabled,
      onToggle: (value) {
        setState(() {
          _systemEnabled = value;
          _actualSystemEnabled = value; // Also update actual state
        });
        _autoSave();
      },
    );
  }

  // AI Nudges section - TEMPORARILY DISABLED (feature being reworked)
  // Widget _buildAINudgesSection() {
  //   return Card(
  //     margin: const EdgeInsets.only(bottom: 12),
  //     child: Padding(
  //       padding: const EdgeInsets.all(16),
  //       child: Column(
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           Row(
  //             children: [
  //               Icon(FeatherIcons.zap, color: Theme.of(context).colorScheme.primary),
  //               const SizedBox(width: 16),
  //               Expanded(
  //                 child: Column(
  //                   crossAxisAlignment: CrossAxisAlignment.start,
  //                   children: [
  //                     Text(
  //                       'AI Nudges',
  //                       style: Theme.of(context).textTheme.titleMedium?.copyWith(
  //                         fontWeight: FontWeight.bold,
  //                       ),
  //                     ),
  //                     Text(
  //                       'Duolingo-style conversation prompts',
  //                       style: Theme.of(context).textTheme.bodySmall?.copyWith(
  //                         color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
  //                       ),
  //                     ),
  //                   ],
  //                 ),
  //               ),
  //               Switch(
  //                 value: _aiNudgesEnabled,
  //                 onChanged: (value) => setState(() => _aiNudgesEnabled = value),
  //               ),
  //             ],
  //           ),
  //           if (_aiNudgesEnabled) ...[
  //             const SizedBox(height: 16),
  //             _buildSliderTile(
  //               'Max Per Day',
  //               'Up to $_aiNudgesMaxPerDay nudges per day',
  //               _aiNudgesMaxPerDay.toDouble(),
  //               1,
  //               5,
  //               (value) => setState(() => _aiNudgesMaxPerDay = value.round()),
  //             ),
  //           ],
  //         ],
  //       ),
  //     ),
  //   );
  // }

  Widget _buildOptionCard({
    required String title,
    required bool enabled,
    required Function(bool) onToggle,
    required String selectedOption,
    required Map<String, String> options,
    required Function(String) onOptionChanged,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Switch(
                  value: enabled,
                  onChanged: onToggle,
                ),
              ],
            ),
            if (enabled) ...[
            const SizedBox(height: 16),
            ...options.entries.map((entry) => 
              _buildRadioOption(
                entry.value,
                selectedOption == entry.key,
                () => onOptionChanged(entry.key),
              ),
            ).toList(),
          ],
        ],
      ),
    ),
    );
  }

  Widget _buildSimpleToggleCard({
    IconData? icon,
    required String title,
    String? subtitle,
    required bool enabled,
    required Function(bool) onToggle,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (icon != null) ...[
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 16),
          ],
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
                if (subtitle != null)
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
    ),
    );
  }

  Widget _buildRadioOption(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
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
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
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
