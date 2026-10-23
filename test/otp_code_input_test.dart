import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/widgets/otp_code_input.dart';

void main() {
  testWidgets('shows placeholder boxes and accepts pasted numeric code', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: OtpCodeInput(controller: controller),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('•'), findsNWidgets(6));
    await tester.enterText(find.byType(TextField), '12a34567');
    await tester.pump();

    expect(controller.text, '123456');
    expect(find.text('•'), findsNothing);
    for (final digit in '123456'.split('')) {
      expect(find.text(digit), findsOneWidget);
    }
  });
}
