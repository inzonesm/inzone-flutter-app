import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class TopicSelectorWidget extends StatefulWidget {
  final String topic;
  final void Function(String topic) callBack;
  final bool
      isSelected; // Add this parameter to receive selection state from parent

  const TopicSelectorWidget({
    super.key,
    required this.topic,
    required this.callBack,
    this.isSelected = false, // Default to false
  });

  @override
  State<TopicSelectorWidget> createState() => _TopicSelectorWidgetState();
}

class _TopicSelectorWidgetState extends State<TopicSelectorWidget> {
  // Remove internal selected state - use widget.isSelected instead

  String replaceAndCapitalize(String text) {
    if (text.contains("_")) {
      List<String> words = text.split('_');

      words = words
          .map((word) => word.replaceFirst(word[0], word[0].toUpperCase()))
          .toList();

      return words.join(' ');
    }
    return "${text[0].toUpperCase()}${text.substring(1).toLowerCase()}";
  }

  void _toggleSelection() {
    // Just call the callback - parent will manage the selection state
    widget.callBack(widget.topic);
  }

  @override
  Widget build(BuildContext context) {
    // Colors for the widget
    const brightBlue = Color(0xFF4E9AF5); // Bright blue color
    const selectedBorderColor = brightBlue;
    final selectedBackgroundColor =
        brightBlue.withOpacity(0.2); // Lighter bright blue
    const unselectedBackgroundColor =
        Color(0xFFE9EDF0); // Light gray color from image

    // Check if dark mode is enabled
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final unselectedTextColor = isDarkMode ? Colors.black87 : Colors.black87;
    final selectedTextColor = isDarkMode ? Colors.white : Colors.black87;

    return GestureDetector(
      onTap: _toggleSelection,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            color: widget.isSelected
                ? selectedBackgroundColor
                : unselectedBackgroundColor,
            border: Border.all(
                color: widget.isSelected
                    ? selectedBorderColor
                    : Colors.transparent,
                width: 1.5)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // if (widget.topic.length > 2) ...[
            //   SvgPicture.asset(
            //     "icons/category_icons/${widget.topic}.svg",
            //     height: 20,
            //     width: 20,
            //     color: widget.isSelected ? selectedBorderColor : unselectedTextColor,
            //   ),
            //   const SizedBox(width: 8),
            // ],
            Text(
              replaceAndCapitalize(widget.topic),
              style: TextStyle(
                color:
                    widget.isSelected ? selectedTextColor : unselectedTextColor,
                fontWeight: FontWeight
                    .normal, // widget.isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Extension to create lighter and darker versions of colors
extension ColorExtension on Color {
  Color get lighter {
    return Color.fromARGB(
      alpha,
      red + ((255 - red) ~/ 2),
      green + ((255 - green) ~/ 2),
      blue + ((255 - blue) ~/ 2),
    );
  }

  Color get darker {
    return Color.fromARGB(
      alpha,
      red ~/ 1.5,
      green ~/ 1.5,
      blue ~/ 1.5,
    );
  }
}
