import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/app_motion.dart';

void main() {
  group('SmoothPageTransitionsBuilder', () {
    testWidgets('uses the shared transition theme on Android', (tester) async {
      expect(
        kSmoothPageTransitionsTheme.builders[TargetPlatform.android],
        isA<SmoothPageTransitionsBuilder>(),
      );
    });

    testWidgets('disables route motion when reduce motion is enabled', (
      tester,
    ) async {
      const childKey = Key('route-child');
      const builder = SmoothPageTransitionsBuilder();
      final route = MaterialPageRoute<void>(
        builder: (_) => const SizedBox(key: childKey),
      );
      Widget? transition;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (context) {
              transition = builder.buildTransitions<void>(
                route,
                context,
                const AlwaysStoppedAnimation<double>(0),
                const AlwaysStoppedAnimation<double>(0),
                const SizedBox(key: childKey),
              );
              return transition!;
            },
          ),
        ),
      );

      expect(transition, isA<SizedBox>());
      expect(find.byKey(childKey), findsOneWidget);
    });

    testWidgets('uses fade, slide, and settle transitions otherwise', (
      tester,
    ) async {
      const builder = SmoothPageTransitionsBuilder();
      final route = MaterialPageRoute<void>(builder: (_) => const SizedBox());
      Widget? transition;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: false),
          child: Builder(
            builder: (context) {
              transition = builder.buildTransitions<void>(
                route,
                context,
                const AlwaysStoppedAnimation<double>(0),
                const AlwaysStoppedAnimation<double>(0),
                const SizedBox(),
              );
              return transition!;
            },
          ),
        ),
      );

      expect(transition, isA<ScaleTransition>());
      expect(find.byType(FadeTransition), findsOneWidget);
      expect(find.byType(SlideTransition), findsOneWidget);
    });
  });

  testWidgets('animates amount changes and honors reduce motion', (
    tester,
  ) async {
    var amount = 10.0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Column(
              children: [
                AnimatedAmountText(
                  value: amount,
                  duration: const Duration(seconds: 1),
                ),
                TextButton(
                  onPressed: () => setState(() => amount = 20),
                  child: const Text('update'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('\u20B910.00'), findsOneWidget);

    await tester.tap(find.text('update'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final halfwayText = tester.widget<Text>(
      find.byWidgetPredicate(
        (widget) => widget is Text && widget.data?.startsWith('\u20B9') == true,
      ),
    );
    expect(halfwayText.data, isNot('\u20B910.00'));
    expect(halfwayText.data, isNot('\u20B920.00'));

    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('\u20B920.00'), findsOneWidget);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: const MaterialApp(
          home: Scaffold(body: AnimatedAmountText(value: 37.5)),
        ),
      ),
    );
    expect(find.text('\u20B937.50'), findsOneWidget);
  });

  testWidgets('mic reflects idle, listening, processing, and tap states', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var listening = false;
    var processing = false;
    var taps = 0;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => Column(
                children: [
                  AnimatedMicButton(
                    listening: listening,
                    processing: processing,
                    onTap: processing ? null : () => taps++,
                  ),
                  TextButton(
                    onPressed: () => setState(() => listening = !listening),
                    child: const Text('toggle listening'),
                  ),
                  TextButton(
                    onPressed: () => setState(() => processing = !processing),
                    child: const Text('toggle processing'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    await tester.tap(find.byType(AnimatedMicButton));
    expect(taps, 1);

    await tester.tap(find.text('toggle listening'));
    await tester.pump();
    expect(find.byIcon(Icons.stop_rounded), findsOneWidget);

    await tester.tap(find.text('toggle processing'));
    await tester.pump();
    expect(find.byIcon(Icons.hourglass_empty_rounded), findsOneWidget);
    expect(find.bySemanticsLabel('Processing voice billing'), findsOneWidget);
    expect(
      tester
          .widget<AnimatedScale>(
            find.descendant(
              of: find.byType(AnimatedMicButton),
              matching: find.byType(AnimatedScale),
            ),
          )
          .duration,
      Duration.zero,
    );
    await tester.tap(find.byType(AnimatedMicButton));
    expect(taps, 1);
    semantics.dispose();
  });
}
