import 'models.dart';
import 'payment_history_storage.dart';

class PayrollExpenseBalance {
  final int workerId;
  final String workerName;
  final double hours;
  final double earned;
  final double paid;
  final double due;

  const PayrollExpenseBalance({
    required this.workerId,
    required this.workerName,
    required this.hours,
    required this.earned,
    required this.paid,
    required this.due,
  });
}

class PayrollExpenseCalculator {
  static List<Map<String, dynamic>> recordsForMonth(
    Iterable<dynamic> records,
    DateTime month,
  ) {
    return records
        .whereType<Map>()
        .where((record) {
          final attendanceDate = DateTime.tryParse(
            (record['attendance_date'] ?? '').toString().split('T').first,
          );
          return attendanceDate != null &&
              attendanceDate.year == month.year &&
              attendanceDate.month == month.month;
        })
        .map((record) => Map<String, dynamic>.from(record))
        .toList();
  }

  static Map<int, PayrollExpenseBalance> calculate({
    required List<Worker> workers,
    required List<Map<String, dynamic>> attendanceRecords,
    required List<WorkerPayment> payments,
    required DateTime month,
    required DateTime now,
  }) {
    final hoursByWorker = <int, double>{};
    for (final record in attendanceRecords) {
      final workerId = int.tryParse(
        (record['worker_id'] ?? record['employee_id'] ?? '').toString(),
      );
      final attendanceDate = DateTime.tryParse(
        (record['attendance_date'] ?? '').toString().split('T').first,
      );
      if (workerId == null ||
          attendanceDate == null ||
          attendanceDate.year != month.year ||
          attendanceDate.month != month.month) {
        continue;
      }
      hoursByWorker.update(
        workerId,
        (hours) => hours + _hoursFor(record, now),
        ifAbsent: () => _hoursFor(record, now),
      );
    }

    final paidByWorker = <int, double>{};
    for (final payment in payments) {
      if (payment.date.year != month.year ||
          payment.date.month != month.month ||
          !payment.amount.isFinite ||
          payment.amount <= 0) {
        continue;
      }
      paidByWorker.update(
        payment.workerId,
        (paid) => paid + payment.amount,
        ifAbsent: () => payment.amount,
      );
    }

    final balances = <int, PayrollExpenseBalance>{};
    for (final worker in workers) {
      final workerId = int.tryParse(worker.id);
      if (workerId == null) continue;

      final hours = hoursByWorker[workerId] ?? 0;
      final rate = worker.salary > 0 && worker.salary.isFinite
          ? worker.salary / 200
          : 0.0;
      final earned = hours * rate;
      final paid = paidByWorker[workerId] ?? 0;
      balances[workerId] = PayrollExpenseBalance(
        workerId: workerId,
        workerName: worker.name,
        hours: hours,
        earned: earned,
        paid: paid,
        due: (earned - paid).clamp(0, double.infinity).toDouble(),
      );
    }
    return balances;
  }

  static double _hoursFor(Map<String, dynamic> record, DateTime now) {
    final totalHours = record['total_working_hours'];
    if (totalHours is num) return _nonNegative(totalHours.toDouble());

    final sessionHours = record['working_hours'];
    if (sessionHours is num) return _nonNegative(sessionHours.toDouble());

    final sessions = record['sessions'];
    if (sessions is Map) {
      var total = 0.0;
      for (final session in sessions.values) {
        if (session is Map && session['working_hours'] is num) {
          total += _nonNegative((session['working_hours'] as num).toDouble());
        }
      }
      if (total > 0) return total;
    }

    final checkIn = _parseAttendanceTime(record['check_in_time']);
    final checkOut = _parseAttendanceTime(record['check_out_time']);
    if (checkIn == null) return 0;
    return _nonNegative((checkOut ?? now).difference(checkIn).inSeconds / 3600);
  }

  static DateTime? _parseAttendanceTime(dynamic raw) {
    if (raw == null) return null;
    final value = raw.toString().trim();
    if (value.isEmpty) return null;
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return null;
    final hasTimezone =
        value.endsWith('Z') || RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(value);
    return hasTimezone ? parsed.toLocal() : parsed;
  }

  static double _nonNegative(double value) =>
      value.isFinite && value > 0 ? value : 0;
}
