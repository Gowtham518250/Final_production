import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/widgets/dashboard/dashboard_action_dock.dart';

void main() {
  testWidgets('keeps dashboard actions on one row when space allows', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(2000, 360));
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

    expect(
      tester.getSize(find.byType(DashboardActionDock)).height,
      lessThanOrEqualTo(88),
    );
    for (final label in labels) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('3'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('dashboard-action-0'))).height,
      lessThan(74),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('dashboard-action-0'))).width,
      136,
    );
    expect(tester.takeException(), isNull);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('dashboard-action-0'))).dx,
      12,
    );

    final firstButtonY = tester
        .getTopLeft(find.byKey(const ValueKey('dashboard-action-0')))
        .dy;
    for (var index = 1; index < labels.length; index++) {
      expect(
        tester.getTopLeft(find.byKey(ValueKey('dashboard-action-$index'))).dy,
        firstButtonY,
      );
    }

    await tester.tap(find.text('Online Orders'));
    expect(tapped, 'Online Orders');
  });

  testWidgets('keeps bottom actions in one horizontally scrollable row', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var tapped = '';
    const labels = ['New Bill', 'Online Orders', 'Gift Card', 'AI Analytics'];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: DashboardActionDock(
            backgroundColor: Colors.white,
            borderColor: Colors.grey,
            items: [
              for (final label in labels)
                DashboardActionItem(
                  icon: Icons.circle,
                  label: label,
                  color: Colors.indigo,
                  onTap: () => tapped = label,
                ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('dashboard-action-3'))).dy,
      tester.getTopLeft(find.byKey(const ValueKey('dashboard-action-0'))).dy,
    );
    await tester.ensureVisible(find.text('AI Analytics'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AI Analytics'));
    expect(tapped, 'AI Analytics');
  });

  testWidgets('renders dashboard actions as distinct colored buttons', (
    tester,
  ) async {
    const colors = [Color(0xFF2563EB), Color(0xFF0F766E), Color(0xFFD97706)];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: DashboardActionDock(
            backgroundColor: Colors.white,
            borderColor: Colors.grey,
            items: [
              for (var index = 0; index < colors.length; index++)
                DashboardActionItem(
                  icon: Icons.circle,
                  label: 'Action $index',
                  color: colors[index],
                  onTap: () {},
                ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final color in colors) {
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Icon && widget.color == color,
        ),
        findsOneWidget,
      );
    }
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Material &&
            widget.borderRadius == BorderRadius.circular(16) &&
            widget.color == Colors.white,
      ),
      findsNWidgets(colors.length),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('fits all dashboard actions on wide screens', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1250, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var tapped = '';
    const labels = [
      'Sale',
      'Language',
      'Voice bill',
      'Online orders',
      'AI Ask',
      'Khata',
      'Help & Support',
      'Gift cards',
      'More',
      'Logout',
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: DashboardActionDock(
            backgroundColor: Colors.white,
            borderColor: Colors.grey,
            items: [
              for (final label in labels)
                DashboardActionItem(
                  icon: Icons.circle,
                  label: label,
                  color: Colors.indigo,
                  onTap: () => tapped = label,
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
    expect(
      tester.getTopRight(find.byKey(const ValueKey('dashboard-action-9'))).dx,
      lessThanOrEqualTo(1250),
    );
    expect(find.text('Logout'), findsOneWidget);
    await tester.tap(find.text('Logout'));
    expect(tapped, 'Logout');
    expect(tester.takeException(), isNull);
  });
}
