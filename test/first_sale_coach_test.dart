import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/first_sale_coach.dart';
import 'package:retail_mind/tutorial_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('first-sale coach skip persists and replay clears it', () async {
    expect(await TutorialService.shouldShowFirstSaleCoach(), isTrue);
    await TutorialService.completeFirstSaleCoach();
    expect(await TutorialService.shouldShowFirstSaleCoach(), isFalse);
    await TutorialService.resetFirstSaleCoach();
    expect(await TutorialService.shouldShowFirstSaleCoach(), isTrue);
  });

  testWidgets('spotlight leaves a hole so the real button still works', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final targetKey = GlobalKey();
    var tapped = false;
    var finished = false;

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: Stack(
          children: [
            Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: targetKey,
                  onPressed: () => tapped = true,
                  child: const Text('New Bill'),
                ),
              ),
            ),
            FirstSaleCoachOverlay(
              steps: [
                FirstSaleCoachStep(
                  targetKey: targetKey,
                  title: 'Start a bill',
                  body: 'Tap New Bill. Add items, then save the sale.',
                ),
              ],
              onFinished: () => finished = true,
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Start a bill'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);

    await tester.tap(find.text('New Bill'));
    await tester.pump();
    expect(tapped, isTrue);

    await tester.tap(find.text('Skip'));
    await tester.pump();
    expect(finished, isTrue);
    expect(await TutorialService.shouldShowFirstSaleCoach(), isFalse);
  });
}
