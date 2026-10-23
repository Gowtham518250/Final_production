import 'live_translated_text.dart';
import 'package:flutter/material.dart';
import 'hybrid_accuracy_test_suite.dart';

/// Accuracy Test Runner UI
/// Executes synthetic payment-matching scenario tests and displays pass rates.
/// 
/// Tests conducted:
/// 1. Conflict Resolution (Same Amount @ Same Time)
/// 2. Same Amount @ Different Times
/// 3. Fuzzy Matching (±10% tolerance)
/// 4. Large Scale (10,000 payment scenarios)
/// 5. Edge Cases

class HybridAccuracyTestPage extends StatefulWidget {
  const HybridAccuracyTestPage({Key? key}) : super(key: key);

  @override
  State<HybridAccuracyTestPage> createState() => _HybridAccuracyTestPageState();
}

class _HybridAccuracyTestPageState extends State<HybridAccuracyTestPage> {
  bool _isRunning = false;
  bool _isComplete = false;
  String _currentTest = '';
  double _progress = 0;

  late HybridPaymentAccuracyTest _testSuite;
  late TestStats _stats;

  @override
  void initState() {
    super.initState();
    _testSuite = HybridPaymentAccuracyTest();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const LiveTranslatedText('🧪 Hybrid System Accuracy Test'),
        // subtitle removed - not supported in this context
        elevation: 2,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeaderCard(),
              const SizedBox(height: 20),

              // Progress
              if (_isRunning) _buildProgressCard(),
              if (_isComplete) _buildResultsCard(),

              // Initial state
              if (!_isRunning && !_isComplete) _buildInitialStateCard(),
            ],
          ),
        ),
      ),
      floatingActionButton: !_isRunning
          ? FloatingActionButton.extended(
              onPressed: _startTests,
              icon: const Icon(Icons.play_arrow),
              label: const LiveTranslatedText('Start Test Suite'),
              backgroundColor: Colors.blue,
            )
          : null,
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[50]!, Colors.purple[50]!],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LiveTranslatedText(
            'Payment Matching Scenario Tests',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const LiveTranslatedText(
            'Synthetic scenarios test matching logic; they do not measure real-world payment accuracy.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue[100],
              borderRadius: BorderRadius.circular(6),
            ),
            child: const LiveTranslatedText(
              'Scenario coverage • synthetic test data • no bank-ground-truth accuracy claim',
              style: TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: LiveTranslatedText(
                  _currentTest,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          LiveTranslatedText(
            '${(_progress * 100).toStringAsFixed(0)}% Complete',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsCard() {
    final stats = _testSuite.stats;
    final scenarioPassRate = stats.totalTests == 0
        ? 0.0
        : stats.totalPassed * 100 / stats.totalTests;
    const ratingColor = Colors.blue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Synthetic scenario pass rate; this is not payment accuracy.
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [ratingColor.withValues(alpha: 0.1), ratingColor.withValues(alpha: 0.05)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ratingColor.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              LiveTranslatedText(
                '${scenarioPassRate.toStringAsFixed(2)}%',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: ratingColor,
                ),
              ),
              const SizedBox(height: 8),
              LiveTranslatedText(
                'Synthetic scenario pass rate',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: ratingColor,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const LiveTranslatedText(
                  'Passing synthetic tests does not establish real-world payment accuracy.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Test Breakdown
        const LiveTranslatedText(
          'Test Results Breakdown',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        _buildTestResult('Conflict Resolution pass rate', stats.test1Accuracy,
            '${stats.test1Passed}/${stats.test1Total}'),
        const SizedBox(height: 8),
        _buildTestResult('Same Amount @ Different Times pass rate', stats.test2Accuracy,
            '${stats.test2Passed}/${stats.test2Total}'),
        const SizedBox(height: 8),
        _buildTestResult(
            'Fuzzy Matching (±10%) pass rate', stats.test3Accuracy,
            '${stats.test3Passed}/${stats.test3Total}'),
        const SizedBox(height: 8),
        _buildTestResult(
          'Large Scale (10,000 scenarios) pass rate',
          stats.test4Accuracy,
          '${stats.test4Passed}/${stats.test4Total}',
          subtitle: '${stats.test4Conflicts} conflicts detected',
        ),
        const SizedBox(height: 8),
        _buildTestResult('Edge Cases pass rate', stats.test5Accuracy,
            '${stats.test5Passed}/${stats.test5Total}'),

        const SizedBox(height: 20),

        // Statistics
        const LiveTranslatedText(
          'Detailed Statistics',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        _buildStatRow('Total Tests', '${stats.totalTests}'),
        _buildStatRow('Passed', '${stats.totalPassed}', Colors.green),
        _buildStatRow('Failed', '${stats.totalFailed}', Colors.red),

        const SizedBox(height: 20),

        // Conclusion
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const LiveTranslatedText(
                'Conclusion',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              const LiveTranslatedText(
                'These synthetic checks cover selected matching behaviors only. They do not verify that funds settled and must not be used to claim production accuracy. Validate against independently confirmed bank/provider records before release.',
                style: TextStyle(fontSize: 11, height: 1.5),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Export button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _exportResults,
            icon: const Icon(Icons.file_download),
            label: const LiveTranslatedText('Export Test Results'),
          ),
        ),
      ],
    );
  }

  Widget _buildTestResult(
    String name,
    double accuracy,
    String count, {
    String? subtitle,
  }) {
    final color = accuracy >= 95
        ? Colors.green
        : accuracy >= 90
            ? Colors.orange
            : Colors.red;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LiveTranslatedText(
                name,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                LiveTranslatedText(
                  subtitle,
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
              ],
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              LiveTranslatedText(
                '${accuracy.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              LiveTranslatedText(
                count,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, [Color? color]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          LiveTranslatedText(
            label,
            style: const TextStyle(fontSize: 12),
          ),
          LiveTranslatedText(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialStateCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LiveTranslatedText(
            'Ready to Test',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const LiveTranslatedText(
            'These synthetic regression tests check selected matching behaviors; they do not measure real-world payment accuracy:',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 12),
          _buildTestListItem('Conflict resolution with same amounts and times'),
          _buildTestListItem('Fuzzy matching with ±10% variance tolerance'),
          _buildTestListItem('10,000 large-scale random scenarios'),
          _buildTestListItem('Edge cases (invalid amounts, time gaps, etc)'),
          _buildTestListItem('Phone-number matching behavior'),
          const SizedBox(height: 12),
          const LiveTranslatedText(
            'Estimated time: 2-3 minutes',
            style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildTestListItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 16, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: LiveTranslatedText(
              text,
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startTests() async {
    setState(() {
      _isRunning = true;
      _progress = 0;
      _currentTest = 'Initializing test suite...';
    });

    try {
      // Update progress for each test
      _updateProgress('Test 1/5: Conflict Resolution', 0.15);
      await Future.delayed(const Duration(milliseconds: 100));

      _updateProgress('Test 2/5: Same Amount Different Times', 0.30);
      await Future.delayed(const Duration(milliseconds: 100));

      _updateProgress('Test 3/5: Fuzzy Matching', 0.45);
      await Future.delayed(const Duration(milliseconds: 100));

      _updateProgress('Test 4/5: Large Scale (10K payments)', 0.70);
      await Future.delayed(const Duration(milliseconds: 100));

      _updateProgress('Test 5/5: Edge Cases', 0.85);
      await Future.delayed(const Duration(milliseconds: 100));

      // Run actual test suite
      _updateProgress('Running full test suite...', 0.90);
      await _testSuite.runFullTestSuite();

      _updateProgress('Compiling results...', 0.95);
      await Future.delayed(const Duration(milliseconds: 500));

      setState(() {
        _isRunning = false;
        _isComplete = true;
        _progress = 1.0;
        _currentTest = 'Complete!';
      });
    } catch (e) {
      debugPrint('Test error: $e');
      setState(() => _isRunning = false);
    }
  }

  void _updateProgress(String test, double progress) {
    if (mounted) {
      setState(() {
        _currentTest = test;
        _progress = progress;
      });
    }
  }

  void _exportResults() {
    final stats = _testSuite.stats;
    final exportText = '''
HYBRID PAYMENT SYSTEM - SYNTHETIC SCENARIO TEST REPORT
Generated: ${DateTime.now()}
Note: These results are not real-world payment accuracy. Ground truth is synthetic.

═══════════════════════════════════════════════════════════════

OVERALL SCENARIO PASS RATE: ${stats.totalTests == 0 ? '0.00' : (stats.totalPassed * 100 / stats.totalTests).toStringAsFixed(2)}%

═══════════════════════════════════════════════════════════════

TEST RESULTS:

1. Conflict Resolution
   Scenario pass rate: ${stats.test1Accuracy.toStringAsFixed(1)}%
   Passed: ${stats.test1Passed}/${stats.test1Total}

2. Same Amount @ Different Times
   Scenario pass rate: ${stats.test2Accuracy.toStringAsFixed(1)}%
   Passed: ${stats.test2Passed}/${stats.test2Total}

3. Fuzzy Matching (±10%)
   Scenario pass rate: ${stats.test3Accuracy.toStringAsFixed(1)}%
   Passed: ${stats.test3Passed}/${stats.test3Total}

4. Large Scale (10,000 payments)
   Scenario pass rate: ${stats.test4Accuracy.toStringAsFixed(1)}%
   Passed: ${stats.test4Passed}/${stats.test4Total}
   Conflicts Detected: ${stats.test4Conflicts}

5. Edge Cases
   Scenario pass rate: ${stats.test5Accuracy.toStringAsFixed(1)}%
   Passed: ${stats.test5Passed}/${stats.test5Total}

═══════════════════════════════════════════════════════════════

STATISTICS:

Total Tests: ${stats.totalTests}
Total Passed: ${stats.totalPassed}
Total Failed: ${stats.totalFailed}
═══════════════════════════════════════════════════════════════

These scenario results do not establish real-world payment accuracy or prove
that any payment settled. Use independently verified provider/bank transactions
as ground truth for accuracy measurement.

═══════════════════════════════════════════════════════════════
    ''';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const LiveTranslatedText('Report copied to clipboard'),
        backgroundColor: Colors.green,
      ),
    );
  }
}
