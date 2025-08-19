import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:inzone/theme/app_colors.dart';

class SubscriptionTile extends StatefulWidget {
  final String price;
  final String coins;
  final VoidCallback onLeftButtonClick;
  final bool isMonth;
  final bool isSelected;

  const SubscriptionTile({
    super.key,
    required this.price,
    required this.coins,
    required this.onLeftButtonClick,
    this.isSelected = false,
    required this.isMonth,
  });

  @override
  _SubscriptionTileState createState() => _SubscriptionTileState();
}

class _SubscriptionTileState extends State<SubscriptionTile> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    final selectedBackgroundColor = isDarkMode
        ? theme.primaryColor
        : Color.alphaBlend(Colors.black.withOpacity(0.05), theme.canvasColor);

    final unselectedTextColor = theme.textTheme.bodySmall?.color ?? Colors.grey;

    final selectedTextColor =
        isDarkMode ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface;

    return GestureDetector(
      onTap: widget.onLeftButtonClick,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:
                  widget.isSelected ? selectedBackgroundColor : theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.isSelected
                    ? theme.primaryColor
                    : AppColors.lightDividerColor,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.isSelected
                          ? isDarkMode
                              ? theme.colorScheme.onPrimary
                              : theme.primaryColor
                          : AppColors.lightDividerColor,
                      width: 2,
                    ),
                  ),
                  child: widget.isSelected
                      ? Center(
                          child: Icon(
                            Icons.check,
                            size: 16,
                            color: isDarkMode
                                ? theme.colorScheme.onPrimary
                                : theme.primaryColor,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        "${widget.price}  ${widget.isMonth ? '/ Month' : ''}",
                        style: TextStyle(
                          color: widget.isSelected
                              ? selectedTextColor
                              : unselectedTextColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          ColorFiltered(
                            colorFilter: isDarkMode
                                ? const ColorFilter.mode(
                                    Colors.white, BlendMode.srcIn)
                                : ColorFilter.mode(
                                    theme.colorScheme.primary, BlendMode.srcIn),
                            child: Image.asset(
                              "icons/settings/balance.png",
                              width: 20,
                              height: 20,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "${widget.coins} Coins ${widget.isMonth ? '/ Month' : ''}",
                            style: TextStyle(
                              color: widget.isSelected
                                  ? selectedTextColor.withOpacity(0.8)
                                  : unselectedTextColor.withOpacity(0.6),
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (widget.isMonth)
            const Positioned(
              top: -6,
              right: 10,
              child: CircleAvatar(
                radius: 14,
                backgroundColor: Colors.redAccent,
                child: Icon(
                  FeatherIcons.heart,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
