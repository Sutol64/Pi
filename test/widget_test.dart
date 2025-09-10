// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance_app_00/main.dart'; // Adjust the import according to your project structure.

void main() {
  testWidgets('App shows TabBar with correct tabs', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the TabBar is present.
    expect(find.byType(TabBar), findsOneWidget);

    // Verify that the correct tabs are present within the TabBar.
    expect(find.descendant(of: find.byType(TabBar), matching: find.text('Dashboard')), findsOneWidget);
    expect(find.descendant(of: find.byType(TabBar), matching: find.text('Editor')), findsOneWidget);
    expect(find.descendant(of: find.byType(TabBar), matching: find.text('Reports')), findsOneWidget);
    expect(find.descendant(of: find.byType(TabBar), matching: find.text('Settings')), findsOneWidget);
  });
}
