import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:health_growth_app/main.dart';

void main() {
  testWidgets('renders configured home widget', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MyApp(home: Scaffold(body: Text('Health Growth'))),
    );

    expect(find.text('Health Growth'), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
