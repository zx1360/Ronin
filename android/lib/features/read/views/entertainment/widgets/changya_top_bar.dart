import 'package:flutter/material.dart';
import 'package:torrid/core/constants/spacing.dart';
import 'package:torrid/features/read/views/entertainment/widgets/changya_user_line.dart';

class ChangyaTopBar extends StatelessWidget {
  final bool useLocal;
  final ValueChanged<bool> onToggle;
  final VoidCallback onRefresh;
  final VoidCallback? onSave;
  final String? nickname;
  final String? gender;
  final String? avatarUrl;
  final bool showUser;

  const ChangyaTopBar({
    super.key,
    required this.useLocal,
    required this.onToggle,
    required this.onRefresh,
    this.onSave,
    this.nickname,
    this.gender,
    this.avatarUrl,
    this.showUser = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasUser = showUser && (((nickname ?? '').isNotEmpty) || ((avatarUrl ?? '').isNotEmpty));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('在线')),
                  ButtonSegment(value: true, label: Text('本地')),
                ],
                selected: {useLocal},
                onSelectionChanged: (s) => onToggle(s.contains(true)),
              ),
              const Spacer(),
              IconButton(
                tooltip: '刷新',
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
              ),
              if (onSave != null)
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.xs),
                  child: FilledButton.icon(
                    onPressed: onSave,
                    icon: const Icon(Icons.save_alt),
                    label: const Text('保存'),
                  ),
                ),
            ],
          ),
          if (hasUser)
            const SizedBox(height: AppSpacing.sm),
          if (hasUser)
            ChangyaUserLine(
              avatarUrl: avatarUrl,
              nickname: nickname ?? '',
              gender: gender ?? '-',
            ),
        ],
      ),
    );
  }
}
