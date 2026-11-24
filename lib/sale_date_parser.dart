/// Parses sale timestamps consistently for dashboard day grouping.
///
/// Date-only values are business-local calendar dates. Timestamp values with
/// an explicit UTC/offset suffix are converted to the device's local timezone;
/// timestamps without a suffix are treated as local wall-clock time.
class SaleDateParser {
  static final RegExp _dateOnlyPattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');
  static final RegExp _timezoneOffsetPattern = RegExp(r'[+-]\d{2}:?\d{2}$');

  static bool hasExplicitTimezone(String value) =>
      value.endsWith('Z') || _timezoneOffsetPattern.hasMatch(value);

  static DateTime parse(Map<String, dynamic> sale) {
    final dateStr = (sale['business_date'] ??
            sale['sale_date'] ??
            sale['invoice_date'] ??
            sale['date'] ??
            sale['created_at'] ??
            sale['createdAt'])
        ?.toString()
        .trim() ?? '';
    if (dateStr.isEmpty) return DateTime(1970);

    try {
      final parsed = DateTime.parse(dateStr);
      if (_dateOnlyPattern.hasMatch(dateStr)) {
        return DateTime(parsed.year, parsed.month, parsed.day);
      }
      if (hasExplicitTimezone(dateStr)) return parsed.toLocal();

      return DateTime(
        parsed.year,
        parsed.month,
        parsed.day,
        parsed.hour,
        parsed.minute,
        parsed.second,
        parsed.millisecond,
        parsed.microsecond,
      );
    } catch (_) {
      return DateTime(1970);
    }
  }
}
