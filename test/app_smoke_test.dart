import 'package:altinus_ocr/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('boots the assignment shell', (tester) async {
    await tester.pumpWidget(const AltinusOcrApp());
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byKey(const ValueKey('ocr-shell')), findsOneWidget);
  });
}
