import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:retail_mind/operation_queue_service.dart';
import 'package:retail_mind/uuid_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory hiveDirectory;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'retail_mind_operation_queue_isolation_test_',
    );
    Hive.init(hiveDirectory.path);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'user_id': 41,
      'user_role': 'OWNER',
    });
    await OperationQueueService.initialize();
    await Hive.box('sync_operations_v2').clear();
    await Hive.box('sync_queue_metadata').clear();
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  Operation operation({
    required String id,
    required int userId,
    required String role,
  }) {
    return Operation(
      operationId: id,
      type: OperationType.createExpense,
      payload: <String, dynamic>{'amount': 10},
      status: OperationStatus.pending,
      retryCount: 0,
      createdTime: DateTime.utc(2026, 11, 6),
      priority: OperationPriority.high,
      deviceId: 'test',
      userId: userId,
      userRole: role,
    );
  }

  test('pending operations are isolated by user ID and role', () async {
    final box = Hive.box('sync_operations_v2');
    await box.put(
      'owner-41',
      operation(id: 'owner-41', userId: 41, role: 'OWNER').toJson(),
    );
    await box.put(
      'owner-72',
      operation(id: 'owner-72', userId: 72, role: 'OWNER').toJson(),
    );
    await box.put(
      'customer-41',
      operation(id: 'customer-41', userId: 41, role: 'CUSTOMER').toJson(),
    );
    await box.put(
      'legacy-owner-41',
      operation(id: 'legacy-owner-41', userId: 41, role: '').toJson()
        ..remove('user_role'),
    );

    final queue = OperationQueueService.instance;
    expect((await queue.getNextOperation())?.operationId, 'owner-41');
    expect((await queue.getPendingOperations()).map((op) => op.operationId), [
      'owner-41',
    ]);
    expect((await queue.getQueueStats()).totalOperations, 1);
    expect(await queue.getOperation('owner-72'), isNull);
    expect(await queue.getOperation('customer-41'), isNull);
    expect(await queue.getOperation('legacy-owner-41'), isNull);

    await queue.clearAll();
    expect(box.containsKey('owner-41'), isFalse);
    expect(box.containsKey('owner-72'), isTrue);
    expect(box.containsKey('customer-41'), isTrue);
    expect(box.containsKey('legacy-owner-41'), isTrue);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('user_id', 72);
    expect((await queue.getNextOperation())?.operationId, 'owner-72');

    await prefs.setInt('user_id', 41);
    await prefs.setString('user_role', 'CUSTOMER');
    expect((await queue.getNextOperation())?.operationId, 'customer-41');
  });
}
