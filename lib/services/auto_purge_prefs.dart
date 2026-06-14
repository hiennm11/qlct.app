import 'package:shared_preferences/shared_preferences.dart';

/// ADR-0045 (P3 #2): persisted setting for auto-purge trash feature.
/// Wraps SharedPreferences keys: `auto_purge_enabled` (bool, default true).
class AutoPurgePrefs {
  AutoPurgePrefs._();

  static const _kEnabledKey = 'auto_purge_enabled';
  static const _kLastPurgeDateKey = 'last_purge_date';

  /// Default ON per UX copy "Danh mục đã xoá sẽ xuất hiện ở đây trong 30 ngày".
  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kEnabledKey) ?? true;
  }

  static Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabledKey, value);
  }

  /// Returns yyyy-MM-dd of last purge run, or null if never.
  static Future<String?> getLastPurgeDate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kLastPurgeDateKey);
  }

  static Future<void> setLastPurgeDate(String dateStr) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastPurgeDateKey, dateStr);
  }
}
