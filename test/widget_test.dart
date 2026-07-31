// test/widget_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fast_resto_bigbonney/main.dart';
import 'package:fast_resto_bigbonney/provider.dart';

void main() {
  testWidgets('App landing screen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (context) => FASTProvider(),
        child: const FASTApp(),
      ),
    );

    // Verify that the brand title FAST is visible
    expect(find.textContaining('FAST'), findsAtLeast(1));
  });
}
