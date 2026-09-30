import 'package:flutter/material.dart';

import 'package:northstar/app/theme.dart';

/// AI 处理层页面共用的展示组件。
///
/// 只服务于本页面，故与页面放在同一个 feature 目录下，不进入 shared。

/// 状态药丸（就绪 / 未就绪 / 运行中）。
class AiStatusPill extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;

  const AiStatusPill({
    super.key,
    required this.text,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        border: Border.all(color: color.withValues(alpha: 0.7)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

/// 能力图标映射。
///
/// 只映射图标（纯展示细节）；能力名称、说明、输入档位与执行者一律由服务端下发，
/// 端上不维护能力语义表，新增能力无需改客户端。
class AiCapabilityIcon {
  static IconData of(String capability) {
    switch (capability) {
      case 'phash':
        return Icons.filter_none_rounded;
      case 'embed':
        return Icons.image_search_rounded;
      case 'face':
        return Icons.face_retouching_natural_rounded;
      case 'ocr':
        return Icons.text_fields_rounded;
      case 'vlm':
        return Icons.auto_awesome_rounded;
      default:
        return Icons.extension_rounded;
    }
  }
}

/// 进度条 + 文案（用于展示待处理/已处理比例）。
class AiProgressBar extends StatelessWidget {
  final int done;
  final int pending;
  final String label;

  const AiProgressBar({
    super.key,
    required this.done,
    required this.pending,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final total = done + pending;
    final ratio = total == 0 ? 1.0 : done / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodySmall),
            ),
            Text(
              '$done / $total',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: AppColors.surfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// 档位徽标：说明这条能力用的是哪个输入图源档。
class AiTierPill extends StatelessWidget {
  final String tier;
  final String note;

  const AiTierPill({super.key, required this.tier, required this.note});

  @override
  Widget build(BuildContext context) {
    if (tier.isEmpty) return const SizedBox.shrink();
    return Tooltip(
      message: note.isEmpty ? tier : '$tier · $note',
      child: AiStatusPill(
        text: tier,
        color: tier == 'ai1024' ? AppColors.info : AppColors.onSurfaceVariant,
        icon: tier == 'ai1024' ? Icons.hd_rounded : Icons.photo_size_select_small,
      ),
    );
  }
}

/// 键值信息行。
class AiInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const AiInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: valueColor),
            ),
          ),
        ],
      ),
    );
  }
}
