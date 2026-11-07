import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:retail_mind/scoped_shared_preferences.dart';
import 'package:retail_mind/utr_deduplication_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ScopedSharedPreferences.setCurrentUserId(11);
  });

  test('Redis cross-device UTR matching is off unless dart-define is set', () {
    expect(UtrDeduplicationService.isDistributedDedupEnabled, isFalse);
  });

  test('UTR cache is isolated per shop user', () async {
    await UtrDeduplicationService.registerUtr('UTR11A');
    expect(await UtrDeduplicationService.checkUtrConflict('UTR11A'), isTrue);

    await ScopedSharedPreferences.setCurrentUserId(22);
    expect(await UtrDeduplicationService.checkUtrConflict('UTR11A'), isFalse);

    await UtrDeduplicationService.registerUtr('UTR22B');
    await ScopedSharedPreferences.setCurrentUserId(11);
    expect(await UtrDeduplicationService.checkUtrConflict('UTR22B'), isFalse);
    expect(await UtrDeduplicationService.checkUtrConflict('UTR11A'), isTrue);
  });
}
