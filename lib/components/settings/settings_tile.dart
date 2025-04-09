import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SettingsTile extends StatelessWidget {
  const SettingsTile(
      {super.key,
      required this.title,
      required this.subtitle,
      // required this.imagePath,
      required this.onPressed,
      this.isLogout = false});
  final String title;
  final String subtitle;
  // String imagePath;
  final VoidCallback onPressed;
  final bool isLogout;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
        decoration: const BoxDecoration(
          color: Colors.white,
        ),
        child: isLogout
            ? Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.logout,
                    color: Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: const TextStyle(
                        fontSize: 16,
                        color: Colors.red,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                            fontWeight: FontWeight.normal),
                      )
                    ],
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.black,
                    size: 16,
                  ),
                ],
              ),
      ),
    );
  }
}
