import 'package:flutter/foundation.dart';

import '../services/storage_service.dart';

/// ADR-0050 (P1 — reactive settings): app-config ChangeNotifier owning
/// user-configurable global settings backed by SharedPreferences (via
/// [StorageService]). First field: `autoPurgeEnabled` (migrate từ
/// `AutoPurgePrefs`, deleted in this epic). Designed extensible cho 6 P+
/// candidates per ADR-0047 §3 (theme, currency, purge interval, voice
/// lang, budget carry, clear all) — mỗi candidate thêm 1 field + 1 setter
/// pattern, không cần restructure.
///
/// Distinguishes từ domain VMs (Expense/Budget/Category/...) — đây là
/// "app-config layer", không own business data. Future cross-VM deps (e.g.
/// [CategoryViewModel.purgeOldTrash] đọc `autoPurgeEnabled`) inject qua
/// `context.read<AppSettingsViewModel>()` thay direct SharedPreferences.
class AppSettingsViewModel extends ChangeNotifier {
  AppSettingsViewModel(this._storage);

  final StorageService _storage;

  // SharedPreferences keys (migrate ownership từ AutoPurgePrefs).
  static const _kAutoPurgeEnabledKey = 'auto_purge_enabled';
  static const _kLastPurgeDateKey = 'last_purge_date';

  // Default ON per UX copy "Danh mục đã xoá sẽ xuất hiện ở đây trong 30 ngày"
  // (ADR-0045 §implement) + `AutoPurgePrefs.isEnabled` precedent.
  bool _autoPurgeEnabled = true;
  String? _lastPurgeDate; // yyyy-MM-dd, null = chưa purge lần nào

  bool get autoPurgeEnabled => _autoPurgeEnabled;
  String? get lastPurgeDate => _lastPurgeDate;

  /// Read persisted values từ [StorageService] và notify listeners. Idempotent —
  /// gọi nhiều lần chỉ re-read 1 lần (cached sau first load). Wire từ
  /// `initState` của SettingsScreen hoặc call sites khác.
  Future<void> load() async {
    final enabled = _storage.loadValue<bool>(_kAutoPurgeEnabledKey);
    _autoPurgeEnabled = enabled ?? true;
    _lastPurgeDate = _storage.loadValue<String>(_kLastPurgeDateKey);
    notifyListeners();
  }

  /// Toggle auto-purge. Early-return nếu value unchanged (tránh spurious
  /// rebuild downstream). Write qua [StorageService] (synchronous get, async
  /// set) rồi notify — subscribers rebuild reactive, không cần pop route.
  Future<void> setAutoPurgeEnabled(bool value) async {
    if (_autoPurgeEnabled == value) return;
    _autoPurgeEnabled = value;
    await _storage.saveValue(_kAutoPurgeEnabledKey, value);
    notifyListeners();
  }

  /// Update `last_purge_date` flag (gate chống double-purge trong cùng ngày
  /// per ADR-0045). Owned bởi VM thay vì static facade để reactive layer
  /// consistent với `autoPurgeEnabled`.
  Future<void> setLastPurgeDate(String dateStr) async {
    if (_lastPurgeDate == dateStr) return;
    _lastPurgeDate = dateStr;
    await _storage.saveValue(_kLastPurgeDateKey, dateStr);
    notifyListeners();
  }
}
