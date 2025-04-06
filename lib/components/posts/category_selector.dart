import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:inzone/data/inzone_category.dart';

class CategorySelector extends StatefulWidget {
  final InZoneCategory category;
  Function(String) onTap;
  final Color startColor;
  final Color endColor;
  final bool isSelected;

  CategorySelector({
    super.key,
    required this.category,
    required this.onTap,
    required this.startColor,
    required this.endColor,
    this.isSelected = false,
  });

  @override
  State<CategorySelector> createState() => _CategorySelectorState();
}

class _CategorySelectorState extends State<CategorySelector> {
  TextEditingController controller = TextEditingController();

  Widget _getSvg(String? iconPath) {
    if (iconPath == null || iconPath.isEmpty) {
      return SvgPicture.asset(
        'icons/category_icons/creativity.svg',
        height: 25,
        width: 25,
      );
    }

    try {
      // Check if the file exists by trying to load it
      return SvgPicture.asset(
        iconPath,
        height: 25,
        width: 25,
        placeholderBuilder: (BuildContext context) {
          return SvgPicture.asset(
            'icons/category_icons/creativity.svg',
            height: 25,
            width: 25,
          );
        },
      );
    } catch (e) {
      return SvgPicture.asset(
        'icons/category_icons/creativity.svg', // Default icon in case of error
        height: 25,
        width: 25,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
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
          border: widget.isSelected
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
    );
  }
}
