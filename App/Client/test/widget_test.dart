import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rppg/main.dart';


void main() {
  testWidgets('app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MyApp(cameras: []),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}