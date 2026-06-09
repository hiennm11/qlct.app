/// Application-wide constants
class AppConstants {
  AppConstants._();

  // App info
  static const String appName = 'Quản Lý Chi Tiêu';
  static const String appVersion = '1.2.0';

  // Storage keys
  static const String transactionsKey = 'transactions';
  static const String settingsKey = 'settings';

  // Date formats
  static const String dateFormat = 'dd/MM/yyyy';
  static const String dateTimeFormat = 'dd/MM/yyyy HH:mm';
  static const String monthYearFormat = 'MM/yyyy';

  // Currency
  static const String currencySymbol = '₫';
  static const String currencyLocale = 'vi_VN';

  // Limits
  static const int maxTransactionsToDisplay = 1000;
  static const int maxExportItems = 10000;
}
