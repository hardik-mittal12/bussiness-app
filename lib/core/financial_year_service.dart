class FinancialYearService {
  /// Calculates the financial year string (e.g., "2025-26") for a given date.
  /// Standard Indian FY rules: April 1 to March 31.
  /// E.g. April 1, 2025 -> "2025-26", March 31, 2026 -> "2025-26", April 1, 2026 -> "2026-27".
  static String getFinancialYear(DateTime date) {
    final year = date.year;
    final month = date.month;

    int startYear;
    if (month >= 4) {
      startYear = year;
    } else {
      startYear = year - 1;
    }

    final endYearShort = (startYear + 1) % 100;
    final endYearStr = endYearShort.toString().padLeft(2, '0');
    return '$startYear-$endYearStr';
  }

  /// Formats sequence identifier key for DB storage (e.g., "2025-26:Sales")
  static String getSequenceId(String financialYear, String voucherType) {
    return '$financialYear:$voucherType';
  }

  /// Returns start and end dates for a financial year string like "2025-26"
  static DateTimeRange getFYDateRange(String financialYear) {
    final parts = financialYear.split('-');
    final startYear = int.parse(parts[0]);
    final endYear = startYear + 1;
    return DateTimeRange(
      start: DateTime(startYear, 4, 1, 0, 0, 0),
      end: DateTime(endYear, 3, 31, 23, 59, 59),
    );
  }
}

class DateTimeRange {
  final DateTime start;
  final DateTime end;
  DateTimeRange({required this.start, required this.end});
}
