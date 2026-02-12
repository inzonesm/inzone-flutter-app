import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inzone/screen/profile/character_creation_screen.dart';

void main() {
  testWidgets('Character creation validation shows error messages', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CharacterCreationScreen(),
        ),
      ),
    );

    // Try to submit with all fields empty
    final createButton = find.text('Create my character');
    expect(createButton, findsOneWidget);

    await tester.tap(createButton);
    await tester.pumpAndSettle();

    // Should show snackbar for missing name
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Character name is required'), findsOneWidget);

    // Fill name, leave description and image empty
    await tester.enterText(find.byType(TextField).first, 'Test Character');
    await tester.tap(createButton);
    await tester.pumpAndSettle();

    // Should show snackbar for missing description
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Character description is required'), findsOneWidget);

    // Fill description, leave image empty
    await tester.enterText(find.byType(TextField).last, 'This is a test character.');
    await tester.tap(createButton);
    await tester.pumpAndSettle();

    // Should show snackbar for missing image
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Character image is required'), findsOneWidget);
  });
}
