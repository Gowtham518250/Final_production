import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/session_management.dart';

void main() {
  group('SessionManagementService refresh rejection guard', () {
    test('401 and 403 are definitive auth rejections', () {
      expect(
        SessionManagementService.shouldTreatRefreshAsRejected(401),
        isTrue,
      );
      expect(
        SessionManagementService.shouldTreatRefreshAsRejected(403),
        isTrue,
      );
    });

    test(
      'network and server failures do not clear the session immediately',
      () {
        expect(
          SessionManagementService.shouldTreatRefreshAsRejected(500),
          isFalse,
        );
        expect(
          SessionManagementService.shouldTreatRefreshAsRejected(502),
          isFalse,
        );
        expect(
          SessionManagementService.shouldTreatRefreshAsRejected(503),
          isFalse,
        );
      },
    );
  });
}
