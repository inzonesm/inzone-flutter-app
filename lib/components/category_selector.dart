import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:inzone/data/inzone_category.dart';


class CategorySelector extends StatefulWidget {
  final InZoneCategory category;
  Function(String) onTap;
  final Color startColor;
  final Color endColor;

  CategorySelector({
    super.key,
    required this.category,
    required this.onTap,
    required this.startColor,
    required this.endColor
  });

  @override
  State<CategorySelector> createState() => _CategorySelectorState();
}

class _CategorySelectorState extends State<CategorySelector> {
  TextEditingController controller = TextEditingController();
  bool isSelected = false; // To manage the selection state

  // Function to get the SVG icon
  Widget _getSvg(String? iconPath) {
    if (iconPath == null || iconPath.isEmpty) {
      return const SizedBox.shrink(); // Return empty widget if path is null or empty
    }

    return SvgPicture.asset(
      iconPath,
      height: 25,
      width: 25,
      placeholderBuilder: (BuildContext context) => const SizedBox(),
    );
  }

  // Function to handle category tap and start the outline fade timer
  void _handleCategoryTap() {
    setState(() {
      isSelected = true;
    });

    // Trigger the onTap callback
    String? value = widget.category.categoryName;
    widget.onTap(value);

    // Start a timer to remove the blue outline after 3 seconds
    Timer(const Duration(seconds: 3), () {
      setState(() {
        isSelected = false; // Remove the outline
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleCategoryTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [widget.startColor, widget.endColor],
            ),
            border: isSelected
                ? Border.all(color: Colors.blueAccent, width: 2.0) // Blue outline
                : null, // No border when not selected
          ),
          child: Row(
            children: [
              _getSvg(widget.category.categoryIconPath),
              const SizedBox(width: 8), // Adjusted for better spacing
              Text(
                widget.category.getCategoryName(),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}