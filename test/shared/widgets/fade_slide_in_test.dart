import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pocket_ledger/shared/widgets/fade_slide_in.dart';

void main() {
  testWidgets('渲染子组件（动画进行中也已挂载）', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FadeSlideIn(child: Text('hello')),
        ),
      ),
    );
    expect(find.text('hello'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('hello'), findsOneWidget);
  });

  testWidgets('delay 仅影响时序，不影响子组件挂载', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FadeSlideIn(
            delay: Duration(milliseconds: 200),
            child: Text('delayed'),
          ),
        ),
      ),
    );
    expect(find.text('delayed'), findsOneWidget);
  });
}
