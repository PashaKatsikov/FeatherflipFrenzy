import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:featherflipfrenzygame/main.dart';

void main() {
  testWidgets('App boots and shows the loading screen', (WidgetTester tester) async {
    await tester.pumpWidget(const FeatherflipApp());
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
