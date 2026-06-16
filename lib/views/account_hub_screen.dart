import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'backup_restore_screen.dart';
import 'category_management_screen.dart';
import 'settings_screen.dart';

/// ADR-0067 (Epic 6 Home — Balanced Note-First): AccountHubScreen — push từ
/// bottom nav index 3. = SettingsScreen (existing ADR-0047) + Category
/// management entry + Backup entry. Mirror SettingsScreen section pattern
/// cho visual consistency.
class AccountHubScreen extends StatelessWidget {
  const AccountHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('hub-account'),
      appBar: AppBar(title: const Text('Tài khoản')),
      body: ListView(
        children: [
          // Section header.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(Icons.tune, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text(
                  'QUẢN LÝ',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            key: const Key('hub-account-settings'),
            leading: const Icon(Icons.settings),
            title: const Text('Cài đặt'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => SettingsScreen.navigateTo(context),
          ),
          ListTile(
            key: const Key('hub-account-categories'),
            leading: const Icon(Icons.category),
            title: const Text('Quản lý danh mục'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => CategoryManagementScreen.navigateTo(context),
          ),
          ListTile(
            key: const Key('hub-account-backup'),
            leading: const Icon(Icons.backup),
            title: const Text('Sao lưu & Khôi phục'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const BackupRestoreScreen(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
