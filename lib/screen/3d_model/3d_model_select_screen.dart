import 'package:flutter/material.dart';

class Model3DSelectScreen extends StatefulWidget {
  final String prompt;
  final String name;

  const Model3DSelectScreen({
    super.key,
    required this.prompt,
    required this.name,
  });

  @override
  State<Model3DSelectScreen> createState() => _Model3DSelectScreenState();
}

class _Model3DSelectScreenState extends State<Model3DSelectScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select 3D Model'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Prompt: ${widget.prompt}'),
            const SizedBox(height: 8),
            Text('Name: ${widget.name}'),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
