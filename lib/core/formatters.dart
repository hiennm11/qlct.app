import 'package:flutter/services.dart';
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

/// TextInputFormatter that formats digits with `.` thousand separators (vi_VN).
/// e.g. "10000000" → "10.000.000"
class ThousandSeparatorFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    // Strip everything except digits
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return newValue.copyWith(text: '');

    // Format with thousand separators
    final formatted = _format(digits);

    // Place cursor at end
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  /// Format raw digits string with `.` every 3 digits from right
  static String _format(String digits) {
    final buffer = StringBuffer();
    final length = digits.length;
    for (int i = 0; i < length; i++) {
      if (i > 0 && (length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  /// Parse a formatted string back to raw digits
  static String strip(String formatted) {
    return formatted.replaceAll(RegExp(r'[^0-9]'), '');
  }
}
