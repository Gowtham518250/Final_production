import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/features/sales_entry/services/voice_nlp_service.dart';

void main() {
  group('VoiceNlpService offline fallback safety', () {
    test('keeps explicit currency context for a spoken price', () {
      final parsed = VoiceNlpService.parseMultipleItems('rice 50 rupees');
      expect(parsed, hasLength(1));
      expect(parsed.single['item'].toString().toLowerCase(), 'rice');
      expect(parsed.single['price'], 50);
      expect(parsed.single['qty'], 1);
    });

    test('keeps unit context for a spoken quantity', () {
      final parsed = VoiceNlpService.parseMultipleItems('2 kg rice');
      expect(parsed, hasLength(1));
      expect(parsed.single['item'].toString().toLowerCase(), 'rice');
      expect(parsed.single['qty'], 2);
    });

    test('does not guess when a lone number has no context', () {
      final parsed = VoiceNlpService.parseMultipleItems('rice 3');
      expect(parsed, isEmpty);
    });

    test('parses quantity and spoken price in the documented order', () {
      final parsed = VoiceNlpService.parseMultipleItems('2 kg rice 50');
      expect(parsed, hasLength(1));
      expect(parsed.single['item'].toString().toLowerCase(), 'rice');
      expect(parsed.single['qty'], 2);
      expect(parsed.single['price'], 50);
    });

    test('does not strip short words that may be part of product names', () {
      final parsed = VoiceNlpService.parseMultipleItems('oil 50 rupees');
      expect(parsed, hasLength(1));
      expect(parsed.single['item'].toString().toLowerCase(), 'oil');
      expect(parsed.single['price'], 50);
    });
  });
}
