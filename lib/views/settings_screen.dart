import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:qlct/viewmodels/app_settings_viewmodel.dart';

/// ADR-0047 (P3 #4): Settings screen — full-screen Scaffold chứa user-configurable
/// global settings. P3 #4 chỉ move auto-purge switch từ CategoryManagementScreen
/// sang đây (bug FAB + che switch). ADR-0050 (P1) refactor binding từ
/// `AutoPurgePrefs` static + load-once → `AppSettingsViewModel` reactive, đóng
/// known limitation ở ADR-0047 §Consequences. Scaffold 1-section hiện tại —
/// sẵn sàng mở rộng P+ (theme, currency, interval, voice lang, budget carry,
/// clear all) mà không cần restructuring. Mỗi P+ item cần grill + contract +
/// ADR riêng trước khi add.
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
  // ADR-0049: app version display. Load async via package_info_plus.
  // Build string format: '{version} (build {buildNumber})'.
  String _appVersionDisplay = '...';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersionDisplay =
            '${info.version} (build ${info.buildNumber})';
      });
    }
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
          // ADR-0050: auto-purge switch bound to AppSettingsViewModel. Selector
          // scopes rebuild tới chỉ field `autoPurgeEnabled` (vs Consumer trên
          // whole VM) — cùng pattern `ProxyProvider<Expense, Budget>`.
          Selector<AppSettingsViewModel, bool>(
            selector: (_, s) => s.autoPurgeEnabled,
            builder: (context, autoPurgeEnabled, _) => SwitchListTile(
              key: Key(
                autoPurgeEnabled
                    ? 'state-auto-purge-enabled'
                    : 'state-auto-purge-disabled',
              ),
              title: const Text('Tự động dọn thùng rác'),
              subtitle: const Text(
                'Các danh mục đã xoá sẽ tự động bị xoá vĩnh viễn sau 30 ngày.',
              ),
              value: autoPurgeEnabled,
              onChanged: (v) => context
                  .read<AppSettingsViewModel>()
                  .setAutoPurgeEnabled(v),
            ),
          ),
          // ADR-0049: App version display section.
          // Section header mirrors the 'Dữ liệu' pattern (line 52-70) for
          // visual consistency. Row is ListTile enabled:false — read-only info,
          // matches Android Settings → About → Version convention.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  'Thông tin',
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
          ListTile(
            key: const Key('state-version-row'),
            leading: const Icon(Icons.smartphone),
            title: const Text('Phiên bản'),
            trailing: Text(
              _appVersionDisplay,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            enabled: false,
          ),
        ],
      ),
    );
  }
}
