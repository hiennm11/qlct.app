import 'package:intl/intl.dart';
import 'constants.dart';

/// Utility class for formatting currency values
class CurrencyFormatter {
  CurrencyFormatter._();

  static final NumberFormat _formatter = NumberFormat.currency(
    locale: AppConstants.currencyLocale,
    symbol: AppConstants.currencySymbol,
    decimalDigits: 0,
  );

  /// Format an amount as currency string
  static String format(int amount) {
    return _formatter.format(amount);
  }

  /// Format an amount with custom locale
  static String formatWithLocale(int amount, String locale) {
    final formatter = NumberFormat.currency(
      locale: locale,
      symbol: AppConstants.currencySymbol,
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }
}

/// Utility class for formatting dates
class DateFormatter {
  DateFormatter._();

  static final DateFormat _dateFormat = DateFormat(AppConstants.dateFormat);
  static final DateFormat _dateTimeFormat = DateFormat(AppConstants.dateTimeFormat);
  static final DateFormat _monthYearFormat = DateFormat(AppConstants.monthYearFormat);

  /// Format a DateTime as date string
  static String formatDate(DateTime date) {
    return _dateFormat.format(date);
  }

  /// Format a DateTime as date-time string
  static String formatDateTime(DateTime dateTime) {
    return _dateTimeFormat.format(dateTime);
  }

  /// Format a DateTime as month-year string
  static String formatMonthYear(DateTime date) {
    return _monthYearFormat.format(date);
  }

  /// Get a relative time string (today, yesterday, etc.)
  static String getRelativeTimeString(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return 'Hôm nay';
    } else if (dateOnly == yesterday) {
      return 'Hôm qua';
    } else {
      return formatDate(date);
    }
  }
}
