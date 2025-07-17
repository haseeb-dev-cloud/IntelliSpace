import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intellispace/main.dart'; // ✅ Updated project name

void main() {
  testWidgets('App loads and shows Login screen', (WidgetTester tester) async {
    await tester.pumpWidget(IntelliSpaceApp());

    // You can adjust this depending on your login screen content
    expect(find.text('Login'), findsOneWidget); // or check for a button, etc.
  });
}
