import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SettingsTile extends StatelessWidget {
  SettingsTile(
      {super.key,
        required this.title,
        required this.imagePath,
        required this.onPressed});
  String title;
  String imagePath;
  VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        color: Colors.black,
      ),
      
      leading: SizedBox(height: 40, width:40, child:  SvgPicture.asset(imagePath)),
      onTap: onPressed,
    );
  }
}
