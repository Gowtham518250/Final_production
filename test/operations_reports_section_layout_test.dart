import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/widgets/dashboard/operations_reports_section.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Operations & Reports keeps View All visible on narrow screens', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OperationsReportsSection(
            onShareDailyReport: () {},
            onWorkerManagementClosed: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('View All'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
