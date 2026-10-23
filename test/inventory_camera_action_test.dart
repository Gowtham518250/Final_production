import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('inventory supports camera capture and existing-photo selection', () {
    final source = File('lib/inventory_page.dart').readAsStringSync();

    expect(source, contains('source: ImageSource.camera'));
    expect(source, contains("label: const LiveTranslatedText('Take photo')"));
    expect(source, contains("label: const LiveTranslatedText('Choose photo')"));
    expect(source, contains("label: const LiveTranslatedText('Hear photo steps')"));
    expect(source, contains('80 * 1024'));
    expect(
      source,
      isNot(contains("label: LiveTranslatedText('Image URL (optional)')")),
      reason: 'Image entry should use camera/photo actions rather than requiring a URL.',
    );
  });
}
