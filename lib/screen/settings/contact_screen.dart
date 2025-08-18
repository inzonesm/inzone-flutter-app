import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:inzone/components/ui/appbar.dart';
import 'package:inzone/components/ui/button.dart';
import 'package:toasty_box/toast_service.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});

  @override
  _ContactScreenState createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final TextEditingController _controller = TextEditingController();
  final int maxLength = 200;

  List<Map<String, dynamic>> items = [
    {"title": "Call Us", "icon": Icons.phone},
    {"title": "Email Us", "icon": Icons.email},
    // {"title": "Chat", "icon": Icons.chat},
  ];

  Widget buildCupertinoInput({
    required String label,
    String? placeholder,
    TextEditingController? controller,
    int maxLines = 1,
    int? maxLength,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey[100] ?? Colors.grey),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                spreadRadius: 2,
                blurRadius: 5,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(10),
          constraints: maxLines > 1
              ? const BoxConstraints(minHeight: 120)
              : const BoxConstraints(),
          child: CupertinoTextField.borderless(
            controller: controller,
            placeholder: placeholder,
            placeholderStyle: const TextStyle(color: Colors.grey),
            style: const TextStyle(color: Colors.black),
            cursorColor: Colors.black,
            maxLines: maxLines,
            maxLength: maxLength,
            clearButtonMode: OverlayVisibilityMode.editing,
            onChanged: (_) {
              if (controller != null) {
                // Trigger rebuild to update length counter if needed
                (controller as dynamic).notifyListeners();
              }
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PreferredSize(
        preferredSize: Size.fromHeight(100),
        child: Padding(
          padding: EdgeInsets.only(top: 2),
          child: CustomAppBar(
            isImage: false,
            title: "Contact Us",
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Image(
              image: AssetImage('assets/images/contactImage.png'),
              height: 300,
            ),
            Wrap(
              spacing: 25.0,
              alignment: WrapAlignment.center,
              children: items.map((item) {
                return ContactTile(
                  title: item['title'],
                  icon: item['icon'],
                  onPressed: () {
                    final title = item['title'];
                    if (title == "Call Us") {
                      launchUrl(Uri.parse("tel:+12272057616"));
                    } else if (title == "Email Us") {
                      launchUrl(Uri.parse("mailto:inzonesm@gmail.com"),
                          mode: LaunchMode.externalApplication);
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  Text('QUICK CONTACT',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          )),
                  const SizedBox(height: 30),
                  buildCupertinoInput(
                      label: "Name", placeholder: "Enter your name"),
                  const SizedBox(height: 20),
                  buildCupertinoInput(
                      label: "Email", placeholder: "Enter your email"),
                  const SizedBox(height: 20),
                  buildCupertinoInput(
                    label: "Messages",
                    placeholder: "Enter your message",
                    controller: _controller,
                    maxLines: 8,
                    maxLength: maxLength,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${_controller.text.length} / $maxLength',
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Button(
                    text: "Send",
                    onPressed: () async {
                      final message = _controller.text.trim();
                      if (message.isEmpty) return;

                      final email = Uri.parse(
                          "mailto:inzonesm@gmail.com?subject=Quick%20Contact&body=${Uri.encodeComponent(message)}");
                      if (await canLaunchUrl(email)) {
                        await launchUrl(email);
                      } else {
                        ToastService.showToast(
                          context,
                          backgroundColor: Theme.of(context).canvasColor,
                          shadowColor: Colors.transparent,
                          leading: const Icon(
                            Icons
                                .error_outline, // or Icons.check_circle, Icons.warning_amber_rounded, etc.
                            color: Colors
                                .redAccent, // or Colors.greenAccent, Colors.orange
                          ),
                          message: "Could not launch email",
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ContactTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onPressed;

  const ContactTile({
    super.key,
    required this.title,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 100,
        width: 100,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 2,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: Colors.black,
            ),
            const SizedBox(height: 5),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
