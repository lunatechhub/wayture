import 'package:flutter_test/flutter_test.dart';
import 'package:wayture/main.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const WaytureApp());
    expect(find.text('Wayture'), findsAny);
  });
}
