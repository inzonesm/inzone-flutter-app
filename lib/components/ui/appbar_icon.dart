import 'package:flutter/material.dart';

class AppbarIcon extends StatelessWidget {
  final VoidCallback? onTap;
  final IconData icon;

  const AppbarIcon({
    super.key,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.cardColor,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(
            icon,
            size: 24,
            color: theme.iconTheme.color,
          ),
        ),
      ),
    );
  }
}
