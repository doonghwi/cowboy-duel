import 'package:cowboy_duel/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('home screen shows the title and a start button',
      (WidgetTester tester) async {
    await tester.pumpWidget(const CowboyDuelApp());
    expect(find.text('카우보이 듀얼'), findsWidgets);
    expect(find.text('CPU와 대결'), findsOneWidget);
  });
}
