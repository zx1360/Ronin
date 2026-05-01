import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:torrid/app/theme/theme_book.dart';
import 'package:torrid/core/constants/spacing.dart';

class ProfilePreferences extends StatelessWidget {
  const ProfilePreferences({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        // 外观设置
        _buildSection(
          title: '外观设置',
          children: [
            _buildSettingTile(
              context: context,
              icon: Icons.image_outlined,
              title: '背景图片',
              subtitle: '设置主页和侧边栏背景图',
              onTap: () => context.pushNamed('profile_background'),
            ),
            _buildSettingTile(
              context: context,
              icon: Icons.format_quote_outlined,
              title: '座右铭',
              subtitle: '管理侧边栏显示的座右铭',
              onTap: () => context.pushNamed('profile_motto'),
            ),
          ],
        ),
      ],
    );
  }

  /// 构建设置分区
  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.sm,
            bottom: AppSpacing.sm,
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.primary,
            ),
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: children,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  /// 构建设置项
  Widget _buildSettingTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primary),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: AppTheme.onSurfaceVariant,
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}