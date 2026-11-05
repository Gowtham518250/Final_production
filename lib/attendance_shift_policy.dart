/// Shared two-shift attendance rules for the Flutter client.
///
/// The backend uses the same stable identifiers:
///   0 = Morning, 09:00–14:00 IST
///   1 = Afternoon, 14:00–23:00 IST
class AttendanceShiftPolicy {
  AttendanceShiftPolicy._();

  static const int morningIndex = 0;
  static const int afternoonIndex = 1;
  static const int requiredShifts = 2;

  static const int morningStartMinutes = 9 * 60;
  static const int afternoonStartMinutes = 14 * 60;
  static const int afternoonEndMinutes = 23 * 60;

  static int? indexForTime(DateTime value) {
    final local = value.toLocal();
    final minutes = local.hour * 60 + local.minute;
    if (minutes >= morningStartMinutes && minutes < afternoonStartMinutes) {
      return morningIndex;
    }
    if (minutes >= afternoonStartMinutes && minutes < afternoonEndMinutes) {
      return afternoonIndex;
    }
    return null;
  }

  static int indexForRecord(Map record) {
    final rawKey = (record['session_key'] ?? record['session'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (rawKey == 'morning') return morningIndex;
    if (rawKey == 'afternoon' || rawKey == 'evening') return afternoonIndex;

    final rawLabel =
        (record['label'] ?? record['session_label'] ?? '').toString().toLowerCase();
    if (rawLabel.contains('morning')) return morningIndex;
    if (rawLabel.contains('afternoon') || rawLabel.contains('evening')) {
      return afternoonIndex;
    }

    final rawCheckIn = record['check_in_time'];
    final checkIn = rawCheckIn == null
        ? null
        : DateTime.tryParse(rawCheckIn.toString());
    if (checkIn != null) {
      final resolved = indexForTime(checkIn);
      if (resolved != null) return resolved;
      return checkIn.toLocal().hour < 14 ? morningIndex : afternoonIndex;
    }

    final rawIndex = int.tryParse((record['session_index'] ?? '').toString());
    if (rawIndex == afternoonIndex) return afternoonIndex;
    return morningIndex;
  }

  static String keyForIndex(int index) =>
      index == morningIndex ? 'morning' : 'afternoon';

  static String labelForIndex(int index) =>
      index == morningIndex ? 'Morning' : 'Afternoon';

  static DateTime shiftStart(DateTime businessDate, int index) {
    final date = DateTime(
      businessDate.year,
      businessDate.month,
      businessDate.day,
    );
    return index == morningIndex
        ? date.add(const Duration(hours: 9))
        : date.add(const Duration(hours: 14));
  }

  static DateTime shiftEnd(DateTime businessDate, int index) {
    final date = DateTime(
      businessDate.year,
      businessDate.month,
      businessDate.day,
    );
    return index == morningIndex
        ? date.add(const Duration(hours: 14))
        : date.add(const Duration(hours: 23));
  }

  static bool isWithinShift(DateTime value, int index) {
    final local = value.toLocal();
    final date = DateTime(local.year, local.month, local.day);
    return !local.isBefore(shiftStart(date, index)) &&
        local.isBefore(shiftEnd(date, index));
  }

  /// Calculates daily status from fixed shift slots. A shift is attended once
  /// it has a check-in; completion additionally requires a valid check-out.
  static Map<String, dynamic> summarize(Iterable<Map> records) {
    final byIndex = <int, Map>{};
    for (final record in records) {
      if (record['check_in_time'] == null) continue;
      byIndex[indexForRecord(record)] = record;
    }

    var completed = 0;
    var open = 0;
    for (final record in byIndex.values) {
      final rawIn = DateTime.tryParse(record['check_in_time'].toString());
      final rawOut = record['check_out_time'] == null
          ? null
          : DateTime.tryParse(record['check_out_time'].toString());
      if (rawIn != null && rawOut != null && !rawOut.isBefore(rawIn)) {
        completed++;
      } else {
        open++;
      }
    }

    final attended = byIndex.length;
    final status = attended == 2
        ? 'PRESENT'
        : (attended == 1 ? 'HALF_DAY' : 'ABSENT');
    return {
      'attendance_status': status,
      'attended_sessions': attended,
      'completed_sessions': completed,
      'open_sessions': open,
      'required_sessions': requiredShifts,
      'attendance_complete': attended == requiredShifts && completed == requiredShifts,
    };
  }
}
