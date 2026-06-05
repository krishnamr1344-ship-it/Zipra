import 'package:flutter_test/flutter_test.dart';

import 'package:zipra/main.dart';

void main() {
  testWidgets('App smoke test - loads without error', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();
  });
}
