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
    return TabBar(
      controller: tabController,
      labelColor: Colors.blue,
      unselectedLabelColor: Colors.black54,
      indicatorColor: Colors.blue,
      indicatorWeight: 3,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: Colors.transparent,
      indicator: const UnderlineTabIndicator(
        borderSide: BorderSide(width: 3, color: Colors.blue),
        insets: EdgeInsets.symmetric(horizontal: 0),
      ),
      labelPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      tabs: tabLabels.map((label) => Tab(text: label)).toList(),
    );
  }
} 