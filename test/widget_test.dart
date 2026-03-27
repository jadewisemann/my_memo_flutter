import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_memo/app.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MyMemoApp()),
    );
    // Just verify the app loads without throwing
    expect(find.text('MyMemo'), findsOneWidget);
  });
}
