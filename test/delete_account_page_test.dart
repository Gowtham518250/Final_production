import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/app_localizations.dart';
import 'package:retail_mind/delete_account_page.dart';

void main() {
  testWidgets(
    'localized deletion phrase accepts surrounding whitespace but rejects mismatches',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('te'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const DeleteAccountPage(),
        ),
      );
      await tester.pumpAndSettle();

      final deleteButton = find.byType(ElevatedButton).first;
      expect(tester.widget<ElevatedButton>(deleteButton).onPressed, isNull);

      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      final phrase = AppLocalizations(
        const Locale('te'),
      ).translate('PERMANENT DELETE');
      await tester.enterText(find.byType(TextField), '  $phrase  ');
      await tester.pump();
      expect(tester.widget<ElevatedButton>(deleteButton).onPressed, isNotNull);

      await tester.enterText(find.byType(TextField), '$phrase wrong');
      await tester.pump();
      expect(tester.widget<ElevatedButton>(deleteButton).onPressed, isNull);
    },
  );
}
