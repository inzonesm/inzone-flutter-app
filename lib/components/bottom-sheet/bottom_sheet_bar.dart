import 'package:flutter/material.dart';


class BottomSheetBar extends StatelessWidget {
  const BottomSheetBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        height: 4, width: 25,
        decoration: BoxDecoration(
          color: Theme.of(context).canvasColor,
          borderRadius: BorderRadius.circular(3)
        ),
      ),
    );
  }
}
