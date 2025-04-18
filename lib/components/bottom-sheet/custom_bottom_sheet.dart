import 'package:flutter/material.dart';


class CustomBottomSheet{

  final Widget child;
  Color backgroundColor;
  bool isNeedMargin;
  final VoidCallback? voidCallback;

  CustomBottomSheet({
    required this.child,
    this.isNeedMargin = false,
    this.voidCallback,
    Color? backgroundColor,
  }):backgroundColor = Colors.white;

  void customBottomSheet(BuildContext context){

    showModalBottomSheet(
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      context: context,
      builder: (BuildContext context) =>
        //   SingleChildScrollView(
        // physics: const ClampingScrollPhysics(),
        // child:
        AnimatedPadding(
          padding: MediaQuery.of(context).viewInsets,
          duration: const Duration(milliseconds: 100),
          curve: Curves.decelerate,
          child: Container(
            margin: isNeedMargin ? const EdgeInsets.only(
                left: 15, right: 15, bottom: 15) : EdgeInsets.zero,
            padding: const EdgeInsets.symmetric(horizontal:16, vertical: 16),
            width: MediaQuery.of(context).size.width,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: isNeedMargin ? BorderRadius.circular(15) : const BorderRadius.vertical(top: Radius.circular(15))
            ),
            child: child,
          ),
        ),
     // )
    ).then((value){
      voidCallback;
    });
  }
}