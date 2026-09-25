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

/// 能力名称与图标的展示映射。
class AiCapabilityMeta {
  final String name;
  final String label;
  final String description;
  final IconData icon;

  const AiCapabilityMeta({
    required this.name,
    required this.label,
    required this.description,
    required this.icon,
  });

  static const all = <AiCapabilityMeta>[
    AiCapabilityMeta(
      name: 'phash',
      label: '感知哈希去重',
      description: '服务进程内计算，无外部依赖',
      icon: Icons.filter_none_rounded,
    ),
    AiCapabilityMeta(
      name: 'embed',
      label: 'SigLIP 语义向量',
      description: '文本搜图 / 以图搜图',
      icon: Icons.image_search_rounded,
    ),
    AiCapabilityMeta(
      name: 'face',
      label: '人脸检测与分组',
      description: 'SCRFD + ArcFace，自动归入人物',
      icon: Icons.face_retouching_natural_rounded,
    ),
    AiCapabilityMeta(
      name: 'ocr',
      label: 'OCR 文字识别',
      description: 'PP-OCR，截图与表情包文字可检索',
      icon: Icons.text_fields_rounded,
    ),
    AiCapabilityMeta(
      name: 'vlm',
      label: 'VLM 自动标注',
      description: 'Ollama 生成描述与关键词，耗时较长',
      icon: Icons.auto_awesome_rounded,
    ),
  ];

  static AiCapabilityMeta of(String name) {
    for (final meta in all) {
      if (meta.name == name) return meta;
    }
    return AiCapabilityMeta(
      name: name,
      label: name,
      description: '',
      icon: Icons.extension_rounded,
    );
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
