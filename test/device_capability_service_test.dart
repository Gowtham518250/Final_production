import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/device_capability_service.dart';

void main() {
  group('DeviceCapabilityService memory parsing', () {
    test('parses MemAvailable from Linux meminfo into GiB', () {
      expect(
        DeviceCapabilityService.parseMemAvailableGiB(const [
          'MemTotal:       2048000 kB',
          'MemFree:         120000 kB',
          'MemAvailable:   1024000 kB',
        ]),
        1024000 / (1024 * 1024),
      );
    });

    test('accepts case-insensitive meminfo units and whitespace', () {
      expect(
        DeviceCapabilityService.parseMemAvailableGiB(const [
          '  memavailable: 524288 kB  ',
        ]),
        0.5,
      );
    });

    test('returns null when MemAvailable is absent or malformed', () {
      expect(
        DeviceCapabilityService.parseMemAvailableGiB(const [
          'MemTotal: 2048000 kB',
        ]),
        isNull,
      );
      expect(
        DeviceCapabilityService.parseMemAvailableGiB(const [
          'MemAvailable: unknown kB',
        ]),
        isNull,
      );
      expect(
        DeviceCapabilityService.parseMemAvailableGiB(const [
          'MemAvailable: 0 kB',
        ]),
        isNull,
      );
    });
  });
}
