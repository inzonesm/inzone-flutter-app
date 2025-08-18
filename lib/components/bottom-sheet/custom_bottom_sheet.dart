import 'package:flutter/material.dart';

class CustomBottomSheet {
  static void show({
    required BuildContext context,
    required Widget child,
    bool isNeedMargin = false,
    VoidCallback? voidCallback,
    Color? backgroundColor,
  }) {
    final ThemeData theme = Theme.of(context);

    showModalBottomSheet(
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      context: context,
      builder: (BuildContext context) {
        return AnimatedPadding(
          padding: MediaQuery.of(context).viewInsets,
          duration: const Duration(milliseconds: 100),
          curve: Curves.decelerate,
          child: Container(
            margin: isNeedMargin
                ? const EdgeInsets.only(left: 15, right: 15, bottom: 15)
                : EdgeInsets.zero,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            width: MediaQuery.of(context).size.width,
            decoration: BoxDecoration(
              color: backgroundColor ?? theme.cardColor,
              borderRadius: isNeedMargin
                  ? BorderRadius.circular(15)
                  : const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Theme(
              data: theme,
              child: child,
            ),
          ),
        );
      },
    ).then((_) {
      if (voidCallback != null) {
        voidCallback();
      }
    });
  }
}
