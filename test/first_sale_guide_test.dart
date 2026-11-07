import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/widgets/dashboard/first_sale_guide.dart';

void main() {
  testWidgets('shows animated sales flow and starts a sale', (tester) async {
    var started = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: FirstSaleGuide(onStartSale: () => started = true)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Open sales'), findsOneWidget);
    expect(find.text('Add products'), findsOneWidget);
    expect(find.text('Try voice billing'), findsOneWidget);
    expect(find.text('Start first sale'), findsOneWidget);
    expect(started, isFalse);

    await tester.tap(find.text('Start first sale'));
    expect(started, isTrue);
  });
}
