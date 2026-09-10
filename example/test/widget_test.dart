import 'package:flutter_test/flutter_test.dart';
import 'package:go_paint_example/main.dart';

void main() {
  testWidgets('KidzCanvasBenchmarkApp builds smoke test',
      (WidgetTester tester) async {
    await tester.pumpWidget(const KidzCanvasBenchmarkApp());
    expect(find.text('Geometry Debugger'), findsWidgets);
  });
}
