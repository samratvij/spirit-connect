import 'package:flutter_test/flutter_test.dart';
import 'package:spirit_connect/main.dart';

void main() {
  testWidgets('App builds', (WidgetTester tester) async {
    await tester.pumpWidget(const SpiritConnectApp());
    expect(find.byType(SpiritConnectApp), findsOneWidget);
  });
}
