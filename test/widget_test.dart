import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fieldlink/main.dart';

void main() {
  testWidgets('App launch test', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ModernMeshHome(),
    ));
    expect(find.byType(ModernMeshHome), findsOneWidget);
  });
}