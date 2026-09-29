import 'package:flutter_test/flutter_test.dart';

import 'package:dlog_new/main.dart';

void main() {
  testWidgets('DLog app launches successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Let the splash screen's 5-second timer complete.
    await tester.pump(const Duration(seconds: 5));

    expect(find.byType(MyApp), findsOneWidget);
  });
}