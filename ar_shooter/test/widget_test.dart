import 'package:flutter_test/flutter_test.dart';
import 'package:ar_shooter/main.dart';

void main() {
  testWidgets('App initializes smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const App());
  });
}
