import 'package:flutter_test/flutter_test.dart';
import 'package:fridge_smart_retrofit/main.dart';

void main() {
  testWidgets('Smart Fridge App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const FridgeSmartApp());
    expect(find.text('ChillSense Console'), findsOneWidget);
  });
}
