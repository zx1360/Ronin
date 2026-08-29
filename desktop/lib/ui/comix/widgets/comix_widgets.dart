import 'package:flutter/material.dart';

import 'package:northstar/app/theme.dart';
import 'package:northstar/domain/comix/models/comix_models.dart';

/// 通用状态徽章（可用/不可用、精确/模糊等）。
class ComixStatusChip extends StatelessWidget {
  final bool ok;
  final String label;

  const ComixStatusChip({super.key, required this.ok, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = ok ? Colors.greenAccent.shade400 : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}

/// 章节状态徽章。
class ChapterStatusChip extends StatelessWidget {
  final String status;

  const ChapterStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      'done' => (Colors.greenAccent.shade400, '完成'),
      'failed' => (Colors.redAccent, '失败'),
      _ => (Colors.blueGrey, '待下'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}

/// 任务状态徽章。
class TaskStatusChip extends StatelessWidget {
  final ComixTaskStatus status;

  const TaskStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      ComixTaskStatus.running => (Colors.blueAccent, '运行中'),
      ComixTaskStatus.finished => (Colors.greenAccent.shade400, '完成'),
      ComixTaskStatus.failed => (Colors.redAccent, '失败'),
      ComixTaskStatus.killed => (Colors.orange, '已中断'),
      ComixTaskStatus.unknown => (Colors.grey, '未知'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: color),
      ),
    );
  }
}

/// 任务结果摘要（下载/失败/新章节/候选数/回收统计等）。
String comixTaskSummary(ComixTask task) {
  final result = task.result;
  if (result == null) return '';
  final ok = result['ok'] == true;
  final data = result['data'];
  if (ok && data is Map<String, dynamic>) {
    final parts = <String>[];
    if (data['title'] is String) {
      parts.add(data['title'].toString());
    }
    if (data['reports'] is List) {
      final reports = data['reports'] as List;
      var newCount = 0;
      for (final report in reports) {
        if (report is Map<String, dynamic>) {
          final news = report['new_chapters'];
          if (news is List) newCount += news.length;
        }
      }
      parts.add('检查 ${reports.length} 部');
      parts.add(newCount > 0 ? '新增 $newCount 章' : '无新章节');
    }
    // add-url 结果嵌套在 data.download 下（协议文档 §4.2），先解包
    final download = data['download'];
    if (download is Map<String, dynamic>) {
      if (download['downloaded'] is List) {
        parts.add('下载 ${(download['downloaded'] as List).length} 章');
      }
      if (download['failed'] is List && (download['failed'] as List).isNotEmpty) {
        parts.add('失败 ${(download['failed'] as List).length} 章');
      }
      if (download['message'] is String &&
          (download['message'] as String).isNotEmpty) {
        parts.add(download['message'].toString());
      }
    }
    if (data['downloaded'] is List) {
      parts.add('下载 ${(data['downloaded'] as List).length} 章');
    }
    if (data['failed'] is List && (data['failed'] as List).isNotEmpty) {
      parts.add('失败 ${(data['failed'] as List).length} 章');
    }
    if (data['message'] is String && (data['message'] as String).isNotEmpty) {
      parts.add(data['message'].toString());
    }
    if (data['recovered_tasks'] != null || data['removed_temp_dirs'] != null) {
      parts.add(
        '回收任务 ${data['recovered_tasks'] ?? 0} · 清理临时目录 ${data['removed_temp_dirs'] ?? 0}',
      );
    }
    if (parts.isNotEmpty) return parts.join(' · ');
    return '完成';
  }
  if (!ok) {
    final error = result['error'] as String? ?? '';
    return '业务错误: $error';
  }
  return '';
}

/// 日志文本样式。
const TextStyle comixLogTextStyle = TextStyle(
  fontSize: 11,
  fontFamily: 'monospace',
  color: AppColors.onSurfaceVariant,
);
