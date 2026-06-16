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

  // ADR-0067 (Epic 6 Home — Balanced Note-First): user-configurable chip
  // count cho NoteEntry quick chip strip. Range [3, 5], default 3.
  static const _kQuickTemplateChipCountKey = 'quick_template_chip_count';
  static const _kQuickTemplateChipCountMin = 3;
  static const _kQuickTemplateChipCountMax = 5;
  static const _kQuickTemplateChipCountDefault = 3;

  // ADR-0056 (Epic 5 — month close flow): per-month dismiss key cho
  // MonthCloseBanner. Suffix = previousMonthYYYYMM (tháng cần chốt), không
  // phải current month. Sang tháng mới tự nhiên reset vì check previousMonth
  // thay đổi → key cũ không còn relevant. SharedPreferences rất nhỏ nên
  // không cần auto-cleanup.
  static const _kMonthCloseDismissedPrefix = 'month_close_dismissed_';

  // Default ON per UX copy "Danh mục đã xoá sẽ xuất hiện ở đây trong 30 ngày"
  // (ADR-0045 §implement) + `AutoPurgePrefs.isEnabled` precedent.
  bool _autoPurgeEnabled = true;
  String? _lastPurgeDate; // yyyy-MM-dd, null = chưa purge lần nào

  // Map yearMonth → dismissed (true) hoặc absent (null). Reactive — gọi
  // setDismissedMonthClose sẽ notify → MonthCloseBanner Selector rebuild
  // với visibility mới. Cache in-memory để tránh hit SharedPreferences mỗi
  // build. Lazy-init qua _ensureDismissedMap() trong getDismissedMonthClose.
  final Map<String, bool> _dismissedMonths = {};

  int _quickTemplateChipCount = _kQuickTemplateChipCountDefault;

  bool get autoPurgeEnabled => _autoPurgeEnabled;
  String? get lastPurgeDate => _lastPurgeDate;
  int get quickTemplateChipCount => _quickTemplateChipCount;

  /// Read persisted values từ [StorageService] và notify listeners. Idempotent —
  /// gọi nhiều lần chỉ re-read 1 lần (cached sau first load). Wire từ
  /// `initState` của SettingsScreen hoặc call sites khác.
  Future<void> load() async {
    final enabled = _storage.loadValue<bool>(_kAutoPurgeEnabledKey);
    _autoPurgeEnabled = enabled ?? true;
    _lastPurgeDate = _storage.loadValue<String>(_kLastPurgeDateKey);
    final chipCountRaw = _storage.loadValue<int>(_kQuickTemplateChipCountKey);
    _quickTemplateChipCount = (chipCountRaw ?? _kQuickTemplateChipCountDefault)
        .clamp(_kQuickTemplateChipCountMin, _kQuickTemplateChipCountMax);
    notifyListeners();
  }

  // ================================================================
  // ADR-0056 (Epic 5 — month close flow): per-month dismiss API
  // ================================================================

  /// `true` nếu user dismissed MonthCloseBanner cho [yearMonth] (format
  /// `yyyyMM`, ví dụ `'202605'`). First call lazy-loads key từ SharedPreferences
  /// rồi cache in-memory.
  bool isMonthCloseDismissed(String yearMonth) {
    if (_dismissedMonths.containsKey(yearMonth)) {
      return _dismissedMonths[yearMonth] ?? false;
    }
    final key = '$_kMonthCloseDismissedPrefix$yearMonth';
    final raw = _storage.loadValue<bool>(key) ?? false;
    _dismissedMonths[yearMonth] = raw;
    return raw;
  }

  /// Set dismiss flag cho [yearMonth]. Idempotent — early-return nếu đã set.
  /// Notify listeners để MonthCloseBanner Selector rebuild (ẩn banner).
  Future<void> setDismissedMonthClose(String yearMonth) async {
    if (_dismissedMonths[yearMonth] == true) return;
    _dismissedMonths[yearMonth] = true;
    final key = '$_kMonthCloseDismissedPrefix$yearMonth';
    await _storage.saveValue(key, true);
    notifyListeners();
  }

  /// Clear dismiss flag (cho Undo snackbar action). Idempotent. Notify listeners
  /// để banner re-show.
  Future<void> clearDismissedMonthClose(String yearMonth) async {
    if (_dismissedMonths[yearMonth] != true) return;
    _dismissedMonths[yearMonth] = false;
    final key = '$_kMonthCloseDismissedPrefix$yearMonth';
    await _storage.saveValue(key, false);
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

  /// ADR-0067: set chip count cho NoteEntry quick chip strip. Clamp to
  /// [3, 5] trước khi write. Notify để NoteEntry rebuild.
  Future<void> setQuickTemplateChipCount(int value) async {
    final clamped = value.clamp(
      _kQuickTemplateChipCountMin,
      _kQuickTemplateChipCountMax,
    );
    if (clamped == _quickTemplateChipCount) return;
    _quickTemplateChipCount = clamped;
    await _storage.saveValue(_kQuickTemplateChipCountKey, clamped);
    notifyListeners();
  }
}
