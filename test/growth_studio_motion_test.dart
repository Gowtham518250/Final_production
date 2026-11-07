import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/growth_studio_motion.dart';

void main() {
  testWidgets('Grow My Shop entry card opens the studio', (tester) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: GrowMyShopEntryCard(onOpen: () => opened = true)),
      ),
    );
    await tester.pump();
    expect(find.text('Grow My Shop'), findsOneWidget);
    await tester.tap(find.text('Grow My Shop'));
    expect(opened, isTrue);
  });

  testWidgets('wizard rail reports the selected step', (tester) async {
    var step = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GrowthWizardRail(step: 1, onStepTap: (value) => step = value),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Goal'));
    expect(step, 0);
  });
}
