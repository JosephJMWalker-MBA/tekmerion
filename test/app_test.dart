import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tekmerion/src/app.dart';

void main() {
  testWidgets('home screen presents the agreement-centered frozen loop',
      (WidgetTester tester) async {
    await tester.pumpWidget(const TekmerionApp());

    expect(find.text('What does this agreement require now?'), findsOneWidget);
    expect(find.text('Upload'), findsOneWidget);
    expect(find.text('Confirm'), findsOneWidget);
    expect(find.text('Remember'), findsOneWidget);
    expect(find.text('Document'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text('Connect'), findsOneWidget);
    expect(find.text('Export'), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
  });
}
