import 'package:flutter/material.dart';
import 'package:inzone/components/category_selector.dart';
import 'package:inzone/config/string_extension.dart';
import 'package:inzone/data/inzone_category.dart';


class CategorySelectorBar extends StatefulWidget {
  List<String> categories = [];
  Function(String) onTap;
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

    return text.capitalize();
  }

  int selectedCategoryIndex = 0;
  int colorIndex = 0;

  @override
  Widget build(BuildContext context) {
    // categories.clear();
    // temp();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: const EdgeInsets.only(left: 10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
              children: List.generate(widget.categories.length, (index) {
                String category = widget.categories[index];
                bool isSelected = index == selectedCategoryIndex;
                if (colorIndex == 5) {
                  colorIndex = 0;
                } else {
                  colorIndex++;
                }

                return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedCategoryIndex = index;
                      });
                    },
                    child: CategorySelector(
                      category: InZoneCategory(
                          categoryName: replaceAndCapitalize(category),
                          index: colorIndex,
                          categoryIconPath: category.length > 2 ? "icons/category_icons/$category.svg" : "icons/category_icons/animals.svg"),
                      onTap: widget.onTap,
                    ));
              })),
        ),
      ),
    );
  }
}
