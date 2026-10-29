import 'dart:async';
import 'dart:io' show ProcessInfo;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart' show FrameTiming, SchedulerBinding;

import 'device_capability_service.dart';

/// Collects lightweight runtime measurements used to evaluate UI performance.
///
/// Only measurements actually supplied by the platform are reported. CPU,
/// battery and thermal values stay unavailable until a real platform sampler is
/// installed; fabricated values must not be used to calculate a performance
/// score or trigger optimization behavior.
class PerformanceMonitorService {
  static PerformanceMonitorService? _instance;

  Timer? _monitoringTimer;
  bool _isMonitoring = false;
  double? _lastFrameTimeMs;
  final List<double> _recentFrameTimes = <double>[];
  final List<PerformanceMetric> _metrics = <PerformanceMetric>[];

  static const int _maxMetrics = 100;
  static const int _maxRecentFrameTimes = 60;
  static const double _highMemoryUsageThreshold = 0.35;
  static const double _slowFrameTimeThreshold = 20;

  PerformanceMonitorService._();

  static PerformanceMonitorService get instance {
    _instance ??= PerformanceMonitorService._();
    return _instance!;
  }

  bool get isMonitoring => _isMonitoring;

  Future<void> startMonitoring() async {
    if (_isMonitoring) return;
    _isMonitoring = true;
    SchedulerBinding.instance.addTimingsCallback(_handleFrameTimings);
    _monitoringTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(_collectMetrics()),
    );
    await _collectMetrics();
  }

  void stopMonitoring() {
    if (!_isMonitoring) return;
    _isMonitoring = false;
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    SchedulerBinding.instance.removeTimingsCallback(_handleFrameTimings);
  }

  void _handleFrameTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      final durationMs = timing.totalSpan.inMicroseconds / 1000.0;
      if (!durationMs.isFinite || durationMs <= 0) continue;
      _recentFrameTimes.add(durationMs);
      if (_recentFrameTimes.length > _maxRecentFrameTimes) {
        _recentFrameTimes.removeAt(0);
      }
    }
    if (_recentFrameTimes.isEmpty) return;
    _lastFrameTimeMs = _recentFrameTimes.reduce((a, b) => a + b) /
        _recentFrameTimes.length;
  }

  Future<void> _collectMetrics() async {
    try {
      final metric = PerformanceMetric(
        timestamp: DateTime.now(),
        memoryUsage: await _getMemoryUsage(),
        cpuUsage: await _getCpuUsage(),
        frameTime: await _getFrameTime(),
        batteryLevel: await _getBatteryLevel(),
        thermalState: await _getThermalState(),
      );
      _metrics.add(metric);
      if (_metrics.length > _maxMetrics) {
        _metrics.removeAt(0);
      }
      _checkPerformanceIssues(metric);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[PerformanceMonitor] Collection failed: $error');
      }
    }
  }

  /// Returns the current Dart process RSS as a fraction of detected device RAM.
  /// This is application memory, not total system memory pressure.
  Future<double?> _getMemoryUsage() async {
    try {
      final totalRamGb = DeviceCapabilityService.instance.capabilities?.totalRAM;
      if (totalRamGb == null || !totalRamGb.isFinite || totalRamGb <= 0) {
        return null;
      }
      final rssBytes = ProcessInfo.currentRss;
      final totalBytes = totalRamGb * 1024 * 1024 * 1024;
      if (rssBytes <= 0 || totalBytes <= 0) return null;
      return (rssBytes / totalBytes).clamp(0.0, 1.0).toDouble();
    } catch (_) {
      return null;
    }
  }

  /// CPU usage is intentionally unavailable instead of a hard-coded estimate.
  Future<double?> _getCpuUsage() async => null;

  /// Flutter's frame timings callback supplies measured render duration.
  Future<double?> _getFrameTime() async => _lastFrameTimeMs;

  /// Battery sampling requires a platform API that is not wired in this app.
  Future<double?> _getBatteryLevel() async => null;

  /// Thermal sampling requires a platform API that is not wired in this app.
  Future<ThermalState?> _getThermalState() async => null;

  void _checkPerformanceIssues(PerformanceMetric metric) {
    final issues = <String>[];
    final memoryUsage = metric.memoryUsage;
    final frameTime = metric.frameTime;

    if (memoryUsage != null && memoryUsage > _highMemoryUsageThreshold) {
      issues.add(
        'App RSS uses ${(memoryUsage * 100).toStringAsFixed(1)}% of detected device RAM',
      );
    }
    if (frameTime != null && frameTime > _slowFrameTimeThreshold) {
      issues.add('Average frame span is ${frameTime.toStringAsFixed(1)}ms');
    }

    if (issues.isNotEmpty && kDebugMode) {
      for (final issue in issues) {
        debugPrint('[PerformanceMonitor] $issue');
      }
    }
  }

  PerformanceSummary getPerformanceSummary() {
    if (_metrics.isEmpty) {
      return const PerformanceSummary(
        averageMemoryUsage: 0,
        averageCpuUsage: 0,
        averageFrameTime: 0,
        performanceScore: 0,
        recommendations: <String>[],
        memoryMeasured: false,
        cpuMeasured: false,
        frameMeasured: false,
      );
    }

    double? average(Iterable<double?> values) {
      final present = values.whereType<double>().toList(growable: false);
      if (present.isEmpty) return null;
      return present.reduce((a, b) => a + b) / present.length;
    }

    final avgMemory = average(_metrics.map((metric) => metric.memoryUsage));
    final avgCpu = average(_metrics.map((metric) => metric.cpuUsage));
    final avgFrame = average(_metrics.map((metric) => metric.frameTime));

    var weightedScore = 0.0;
    var availableWeight = 0.0;
    if (avgMemory != null) {
      weightedScore +=
          (1.0 - avgMemory.clamp(0.0, 1.0).toDouble()) * 40.0;
      availableWeight += 40.0;
    }
    if (avgCpu != null) {
      weightedScore += (1.0 - avgCpu.clamp(0.0, 1.0).toDouble()) * 30.0;
      availableWeight += 30.0;
    }
    if (avgFrame != null) {
      weightedScore +=
          (1.0 - (avgFrame / 33.0).clamp(0.0, 1.0).toDouble()) * 30.0;
      availableWeight += 30.0;
    }
    final score = availableWeight == 0
        ? 0
        : (weightedScore / availableWeight * 100).round().clamp(0, 100).toInt();

    final recommendations = <String>[];
    if (avgMemory != null && avgMemory > _highMemoryUsageThreshold) {
      recommendations.add('Reduce app memory use and review image/model caches');
    }
    if (avgCpu != null && avgCpu > 0.7) {
      recommendations.add('Profile CPU-heavy work on the affected screen');
    }
    if (avgFrame != null && avgFrame > _slowFrameTimeThreshold) {
      recommendations.add('Profile expensive widget builds and frame rendering');
    }

    return PerformanceSummary(
      averageMemoryUsage: avgMemory ?? 0,
      averageCpuUsage: avgCpu ?? 0,
      averageFrameTime: avgFrame ?? 0,
      performanceScore: score,
      recommendations: recommendations,
      memoryMeasured: avgMemory != null,
      cpuMeasured: avgCpu != null,
      frameMeasured: avgFrame != null,
    );
  }

  List<PerformanceMetric> getMetricsHistory({int? limit}) {
    if (limit != null && _metrics.length > limit) {
      return _metrics.sublist(_metrics.length - limit);
    }
    return List<PerformanceMetric>.from(_metrics);
  }

  void clearMetrics() {
    _metrics.clear();
  }

  Future<String> exportPerformanceReport() async {
    final summary = getPerformanceSummary();
    final buffer = StringBuffer()
      ..writeln('PERFORMANCE REPORT')
      ..writeln('Generated: ${DateTime.now().toIso8601String()}')
      ..writeln()
      ..writeln('Performance Score: ${summary.performanceScore}/100');

    buffer.writeln(
      summary.memoryMeasured
          ? 'App RSS / device RAM: ${(summary.averageMemoryUsage * 100).toStringAsFixed(1)}%'
          : 'App RSS / device RAM: N/A',
    );
    buffer.writeln(
      summary.cpuMeasured
          ? 'Average CPU Usage: ${(summary.averageCpuUsage * 100).toStringAsFixed(1)}%'
          : 'Average CPU Usage: N/A (not sampled)',
    );
    buffer.writeln(
      summary.frameMeasured
          ? 'Average frame span: ${summary.averageFrameTime.toStringAsFixed(1)}ms'
          : 'Average frame span: N/A (no frame timings received)',
    );
    buffer.writeln('Battery: N/A (not sampled)');
    buffer.writeln('Thermal state: N/A (not sampled)');
    buffer.writeln();
    buffer.writeln('Recommendations:');
    for (final recommendation in summary.recommendations) {
      buffer.writeln('  - $recommendation');
    }
    return buffer.toString();
  }
}

class PerformanceMetric {
  final DateTime timestamp;
  final double? memoryUsage;
  final double? cpuUsage;
  final double? frameTime;
  final double? batteryLevel;
  final ThermalState? thermalState;

  const PerformanceMetric({
    required this.timestamp,
    required this.memoryUsage,
    required this.cpuUsage,
    required this.frameTime,
    required this.batteryLevel,
    required this.thermalState,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'memory_usage': memoryUsage,
        'cpu_usage': cpuUsage,
        'frame_time': frameTime,
        'battery_level': batteryLevel,
        'thermal_state': thermalState?.toString(),
      };
}

enum ThermalState { normal, warm, hot }

class PerformanceSummary {
  final double averageMemoryUsage;
  final double averageCpuUsage;
  final double averageFrameTime;
  final int performanceScore;
  final List<String> recommendations;
  final bool memoryMeasured;
  final bool cpuMeasured;
  final bool frameMeasured;

  const PerformanceSummary({
    required this.averageMemoryUsage,
    required this.averageCpuUsage,
    required this.averageFrameTime,
    required this.performanceScore,
    required this.recommendations,
    this.memoryMeasured = true,
    this.cpuMeasured = true,
    this.frameMeasured = true,
  });
}
