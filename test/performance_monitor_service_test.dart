import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/performance_monitor_service.dart';

void main() {
  group('Performance telemetry', () {
    test('unsupported platform readings are represented as unavailable', () {
      final metric = PerformanceMetric(
        timestamp: DateTime.utc(2026, 1, 1),
        memoryUsage: null,
        cpuUsage: null,
        frameTime: null,
        batteryLevel: null,
        thermalState: null,
      );

      final json = metric.toJson();
      expect(json['memory_usage'], isNull);
      expect(json['cpu_usage'], isNull);
      expect(json['frame_time'], isNull);
      expect(json['battery_level'], isNull);
      expect(json['thermal_state'], isNull);
    });

    test('summary can explicitly mark telemetry that was not measured', () {
      const summary = PerformanceSummary(
        averageMemoryUsage: 0,
        averageCpuUsage: 0,
        averageFrameTime: 0,
        performanceScore: 0,
        recommendations: <String>[],
        memoryMeasured: false,
        cpuMeasured: false,
        frameMeasured: false,
      );

      expect(summary.memoryMeasured, isFalse);
      expect(summary.cpuMeasured, isFalse);
      expect(summary.frameMeasured, isFalse);
    });

    test('empty monitor does not claim a measured performance score', () {
      final summary =
          PerformanceMonitorService.instance.getPerformanceSummary();

      expect(summary.performanceScore, 0);
      expect(summary.memoryMeasured, isFalse);
      expect(summary.cpuMeasured, isFalse);
      expect(summary.frameMeasured, isFalse);
    });
  });
}
