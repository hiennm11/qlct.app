import 'package:flutter/material.dart';
import 'package:qlct/services/auto_purge_prefs.dart';

/// ADR-0047 (P3 #4): Settings screen — full-screen Scaffold chứa user-configurable
/// global settings. P3 #4 chỉ move auto-purge switch từ CategoryManagementScreen
/// sang đây (bug FAB + che switch). Scaffold 1-section hiện tại — sẵn sàng mở rộng
/// P+ (theme, currency, interval, voice lang, budget carry, clear all) mà không
/// cần restructuring. Mỗi P+ item cần grill + contract + ADR riêng trước khi add.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  static void navigateTo(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // ADR-0045 + ADR-0047: local mirror of AutoPurgePrefs.enabled. Load async in
  // initState, write back on change.
  bool _autoPurgeEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadAutoPurgePref();
  }

  Future<void> _loadAutoPurgePref() async {
    final enabled = await AutoPurgePrefs.isEnabled();
    if (mounted) setState(() => _autoPurgeEnabled = enabled);
  }

  Future<void> _setAutoPurgePref(bool value) async {
    await AutoPurgePrefs.setEnabled(value);
    setState(() => _autoPurgeEnabled = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt'),
      ),
      body: ListView(
        children: [
          // Section header (ADR-0047 §2 — ListView + section header pattern).
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(Icons.folder_outlined, size: 18, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  'Dữ liệu',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          // Auto-purge setting (moved from CategoryManagementScreen Trash section).
          SwitchListTile(
            key: Key(
              _autoPurgeEnabled
                  ? 'state-auto-purge-enabled'
                  : 'state-auto-purge-disabled',
            ),
            title: const Text('Tự động dọn thùng rác'),
            subtitle: const Text(
              'Các danh mục đã xoá sẽ tự động bị xoá vĩnh viễn sau 30 ngày.',
            ),
            value: _autoPurgeEnabled,
            onChanged: _setAutoPurgePref,
          ),
        ],
      ),
    );
  }
}
