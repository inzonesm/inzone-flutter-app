import 'package:flutter/material.dart';
import 'package:inzone/components/category_selector.dart';
import 'package:inzone/config/string_extension.dart';
import 'package:inzone/data/inzone_category.dart';


class CategorySelectorBar extends StatefulWidget {
  List<String> categories = [];
  Function(String?) onTap;
  CategorySelectorBar(
      {super.key, required this.categories, required this.onTap});

  @override
  State<CategorySelectorBar> createState() => _CategorySelectorBarState();
}
class _CategorySelectorBarState extends State<CategorySelectorBar> {
  String replaceAndCapitalize(String text) {
    // Split the text into words based on underscores.
    if (text.contains("_")) {
      List<String> words = text.split('_');

      // Capitalize the first letter of each word.
      words = words
          .map((word) => word.replaceFirst(word[0], word[0].toUpperCase()))
          .toList();

      // Join the words back together with spaces.
      return words.join(' ');
    }

    return text.capitalize(); // Assuming you have a capitalize() extension on String
  }

  int? selectedCategoryIndex;
  // final List<Color> startColorList = [
  //   const Color(0xff8674ED),
  //   const Color(0xff26DD90),
  //   const Color(0xff8674ED),
  //
  //   const Color(0xffFFCB8D),
  //   const Color(0xff8674ED),
  //   const Color(0xff26DD90),
  //   const Color(0xffFFCB8D),
  //
  // ];
  // final List<Color> endColorList = [
  //   const Color(0xff6048DA),
  //   const Color(0xff0EB16D),
  //   const Color(0xff6048DA),
  //
  //   const Color(0xffFFB26A),
  //   const Color(0xff6048DA),
  //   const Color(0xff0EB16D),
  //   const Color(0xffFFB26A),
  // ];
  final List<Color> startColorList = [
    const Color(0xffFF6B6B),  // Light Red
    const Color(0xff4ECDC4),  // Turquoise
    const Color(0xffFFD93D),  // Yellow
    const Color(0xffFF9F1C),  // Orange
    const Color(0xff2EC4B6),  // Mint Green
    const Color(0xff8338EC),  // Purple
    const Color(0xff06D6A0),  // Bright Green
    const Color(0xff3A86FF),  // Sky Blue
    const Color(0xffFF006E),  // Pink
    const Color(0xffEF476F),  // Bright Pinkish Red
    const Color(0xff118AB2),  // Blue
    const Color(0xff073B4C),  // Dark Teal
    const Color(0xffFFD166),  // Soft Yellow
    const Color(0xff06BA63),  // Emerald Green
    const Color(0xffF77F00),  // Bright Orange
  ];

  final List<Color> endColorList = [
    const Color(0xffF06543),  // Darker Red
    const Color(0xff11999E),  // Teal
    const Color(0xffFEC260),  // Golden Yellow
    const Color(0xffF46036),  // Dark Orange
    const Color(0xff197278),  // Dark Teal
    const Color(0xff3A0CA3),  // Deep Purple
    const Color(0xff40916C),  // Darker Green
    const Color(0xff005F99),  // Deep Blue
    const Color(0xffFB5607),  // Bright Orange
    const Color(0xffD62828),  // Dark Red
    const Color(0xff073B4C),  // Darker Blue
    const Color(0xff0A9396),  // Aquatic Blue
    const Color(0xffBC6C25),  // Burnt Orange
    const Color(0xff0C7489),  // Dark Emerald
    const Color(0xffB86200),  // Deep Orange
  ];



  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: const EdgeInsets.only(left: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: List.generate(widget.categories.length, (index) {
            String category = widget.categories[index];
            bool isSelected = index == selectedCategoryIndex;
            String capitalizedCategory = replaceAndCapitalize(category);

            // Use modulo to loop through the color lists
            int colorIndex = index % startColorList.length;
            
            // Construct the icon path and log it for debugging
            String categoryIconPath = category.length > 2
                ? "icons/category_icons/$category.svg"
                : "icons/category_icons/creativity.svg";
            
            print("Category: $category, Icon Path: $categoryIconPath");

            return GestureDetector(
              onTap: () {
                print("Category tapped: $capitalizedCategory, index: $index, currently selected: $selectedCategoryIndex");
                
                setState(() {
                  // If the same category is tapped again, deselect it
                  if (selectedCategoryIndex == index) {
                    selectedCategoryIndex = null;
                    widget.onTap(null); // Pass null to indicate no category is selected
                  } else {
                    selectedCategoryIndex = index;
                    print("Setting selected category to: $capitalizedCategory");
                    widget.onTap(category); // Pass the original category for filtering
                  }
                });
              },
              child: CategorySelector(
                startColor: startColorList[colorIndex],
                endColor: endColorList[colorIndex],
                isSelected: isSelected,
                category: InZoneCategory(
                  categoryName: capitalizedCategory,
                  index: colorIndex,
                  categoryIconPath: categoryIconPath,
                ),
                onTap: (_) {
                  // We're handling the tap in the InkWell above
                  // This is just a placeholder to satisfy the required parameter
                },
              ),
            );
          }),
        ),
      ),
    );
  }
}
