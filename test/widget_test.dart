import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_internet_ibm_datathon/main.dart';

void main() {
  testWidgets('App launch test', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ModernMeshHome(),
    ));
    expect(find.byType(ModernMeshHome), findsOneWidget);
  });
}