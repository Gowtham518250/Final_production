import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/widgets/dashboard/dashboard_action_dock.dart';

void main() {
  testWidgets('shows all dashboard actions and navigates when tapped', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var tapped = '';
    final labels = [
      'New Bill',
      'Online Orders',
      'Gift Card',
      'AI Analytics',
      'Language',
      'Daily Closing',
      'How to Use',
      'More & Settings',
      'Logout',
    ];
    final colors = [
      const Color(0xFF4F46E5),
      const Color(0xFFD97706),
      const Color(0xFFDB2777),
      const Color(0xFF7C3AED),
      const Color(0xFF2563EB),
      const Color(0xFF0F766E),
      const Color(0xFF059669),
      const Color(0xFF475569),
      const Color(0xFFDC2626),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: DashboardActionDock(
            backgroundColor: Colors.white,
            borderColor: Colors.grey,
            items: [
              for (var index = 0; index < labels.length; index++)
                DashboardActionItem(
                  icon: Icons.circle,
                  label: labels[index],
                  color: colors[index],
                  primary: index == 0,
                  badgeCount: index == 1 ? 3 : 0,
                  onTap: () => tapped = labels[index],
                ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final label in labels) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('3'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Online Orders'));
    expect(tapped, 'Online Orders');
  });
}
