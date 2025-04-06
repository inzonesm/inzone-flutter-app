import 'package:flutter/material.dart';

class Button extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final EdgeInsetsGeometry padding;
  final bool isLoginPage;
  Button({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoginPage = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
  });

  List<Color> loginPage = [const Color(0xFF14CFEE), const Color(0xFF2196F3)];
  List<Color> others = [const Color(0xFF29BABB), const Color(0xFF135555)];
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 56,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isLoginPage ? loginPage : others,
          ),
        ),
        child: Center(
          child: Padding(
            padding: padding,
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
