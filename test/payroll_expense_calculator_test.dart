import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/models.dart';
import 'package:retail_mind/payment_history_storage.dart';
import 'package:retail_mind/payroll_expense_calculator.dart';

Worker _worker({String id = '7', double salary = 20000}) => Worker(
  id: id,
  name: 'Ravi',
  phone: '',
  address: '',
  salary: salary,
  assignedWork: '',
  position: 'Staff',
  joinDate: DateTime(2024),
  status: 'active',
);

void main() {
  final month = DateTime(2026, 11);
  final now = DateTime(2026, 11, 6, 18);

  test('keeps only records from the selected month', () {
    final records = PayrollExpenseCalculator.recordsForMonth([
      {'worker_id': 7, 'attendance_date': '2026-11-02'},
      {'worker_id': 7, 'attendance_date': '2026-10-31'},
      {'worker_id': 7, 'attendance_date': 'invalid'},
    ], month);

    expect(records, hasLength(1));
    expect(records.single['attendance_date'], '2026-11-02');
  });

  test('subtracts monthly worker payments from attendance payroll', () {
    final balances = PayrollExpenseCalculator.calculate(
      workers: [_worker()],
      attendanceRecords: [
        {'worker_id': 7, 'attendance_date': '2026-11-02', 'working_hours': 8.0},
        {
          'employee_id': 7,
          'attendance_date': '2026-11-03',
          'total_working_hours': 6.0,
        },
      ],
      payments: [
        WorkerPayment(
          id: 'p1',
          workerId: 7,
          amount: 500,
          note: '',
          type: 'Advance',
          date: DateTime(2026, 11, 4),
        ),
      ],
      month: month,
      now: now,
    );

    final balance = balances[7]!;
    expect(balance.hours, 14);
    expect(balance.earned, 1400);
    expect(balance.paid, 500);
    expect(balance.due, 900);
  });

  test('does not make paid payroll negative or include other months', () {
    final balances = PayrollExpenseCalculator.calculate(
      workers: [_worker()],
      attendanceRecords: [
        {'worker_id': 7, 'attendance_date': '2026-11-02', 'working_hours': 8.0},
        {
          'worker_id': 7,
          'attendance_date': '2026-10-31',
          'working_hours': 100.0,
        },
      ],
      payments: [
        WorkerPayment(
          id: 'p1',
          workerId: 7,
          amount: 1000,
          note: '',
          type: 'Salary',
          date: DateTime(2026, 11, 4),
        ),
        WorkerPayment(
          id: 'p2',
          workerId: 7,
          amount: 5000,
          note: '',
          type: 'Salary',
          date: DateTime(2026, 10, 4),
        ),
      ],
      month: month,
      now: now,
    );

    expect(balances[7]!.earned, 800);
    expect(balances[7]!.paid, 1000);
    expect(balances[7]!.due, 0);
  });
}
