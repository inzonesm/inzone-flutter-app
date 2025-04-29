import 'package:flutter/material.dart';

class ProfileTabs extends StatelessWidget {
  final TabController tabController;
  final List<String> tabLabels;

  const ProfileTabs({
    super.key,
    required this.tabController,
    required this.tabLabels,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TabBar(
      controller: tabController,
      labelColor: theme.colorScheme.primary,
      unselectedLabelColor: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
      indicatorColor: theme.colorScheme.primary,
      indicatorWeight: 3,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: Colors.transparent,
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(width: 3, color: theme.colorScheme.primary),
        insets: const EdgeInsets.symmetric(horizontal: 0),
      ),
      labelPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      tabs: tabLabels.map((label) => Tab(text: label)).toList(),
    );
  }
}
