import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class TopicSelectorWidget extends StatefulWidget {
  String topic;
  void Function(String topic) callBack;

  TopicSelectorWidget({super.key, required this.topic, required this.callBack});

  @override
  State<TopicSelectorWidget> createState() => _TopicSelectorWidgetState();
}

class _TopicSelectorWidgetState extends State<TopicSelectorWidget> {
  bool selected = false;
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          selected = !selected;
          if (selected) {
            widget.callBack(widget.topic);
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.secondary,
            boxShadow: [
              BoxShadow(
                  color: Theme.of(context).primaryColor.withOpacity(0.2),
                  spreadRadius: 3,
                  offset: const Offset(0, 5),
                  blurRadius: 7)
            ]),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              widget.topic.length > 2
                  ? "icons/category_icons/${widget.topic}.svg"
                  : "icons/category_icons/animals.svg",
              height: 25,
              width: 25,
            ),
            const SizedBox(
              width: 10,
            ),
            Text(replaceAndCapitalize(widget.topic),
                style: selected
                    ? const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)
                    : const TextStyle(color: Colors.black)),
          ],
        ),
      ),
    );
  }
}
