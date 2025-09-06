import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:productivity_app/main.dart';

void main() {
  testWidgets('Welcome page renders form fields', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Welcome'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('Age'), findsOneWidget);
    expect(find.text('Gender'), findsOneWidget);
    expect(find.text('Goal'), findsOneWidget);
  });
}

