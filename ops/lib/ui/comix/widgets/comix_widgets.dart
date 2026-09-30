import 'package:flutter/material.dart';

import 'package:northstar/app/theme.dart';
import 'package:northstar/domain/comix/models/comix_models.dart';

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

/// 任务状态 → (颜色, 标签) 的统一映射：任务面板徽章与网址下载结果共用，
/// 避免两处 switch 各自漂移。
///
/// [businessFailure] 用于把"进程正常结束但业务结果 ok=false/非零退出码"的任务
/// 标成失败，而不是绿色"完成"（后端把退出码 2 记为 finished）。
/// [unknownStyle] 由调用方给出：`unknown` 在不同上下文语义不同（任务面板=未知，
/// 网址下载=已提交待出现 / 提交失败），其余状态统一。
(Color, String) comixTaskStatusStyle(
  ComixTaskStatus status, {
  bool businessFailure = false,
  (Color, String)? unknownStyle,
}) {
  if (status == ComixTaskStatus.unknown) {
    return unknownStyle ?? (Colors.grey, '未知');
  }
  return switch (status) {
    ComixTaskStatus.running => (Colors.blueAccent, '运行中'),
    ComixTaskStatus.finished =>
      businessFailure
          ? (Colors.redAccent, '业务错误')
          : (Colors.greenAccent.shade400, '完成'),
    ComixTaskStatus.failed => (Colors.redAccent, '失败'),
    ComixTaskStatus.killed => (Colors.orange, '已中断'),
    ComixTaskStatus.unknown => (Colors.grey, '未知'),
  };
}

/// 任务状态徽章。
class TaskStatusChip extends StatelessWidget {
  final ComixTaskStatus status;
  final bool businessFailure;

  const TaskStatusChip({
    super.key,
    required this.status,
    this.businessFailure = false,
  });

  @override
  Widget build(BuildContext context) {
    final (color, label) = comixTaskStatusStyle(
      status,
      businessFailure: businessFailure,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color)),
    );
  }
}

/// 任务结果摘要（下载/失败/新章节/追更进度/回收统计等）。
///
/// 后端 `/tasks` 列表已带 result，因此任务结束后摘要依然可见（不再随详情消失）。
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
      parts.addAll(_updateCheckSummary(data['reports'] as List));
    }
    // add-url / update-check 的下载结果嵌套在 data.download 下（协议文档 §4.2/§4.4）
    final download = data['download'];
    if (download is Map<String, dynamic>) {
      parts.addAll(_downloadSummary(download, prefix: '新章节'));
    }
    if (data['downloaded'] is List || data['failed'] is List) {
      parts.addAll(_downloadSummary(data));
    }
    if (data['recovered_tasks'] != null || data['removed_temp_dirs'] != null) {
      parts.add(
        '回收任务 ${data['recovered_tasks'] ?? 0} · 清理临时目录 ${data['removed_temp_dirs'] ?? 0}',
      );
    }
    if (data['already_exists'] == true) {
      parts.add('已登记过，复用现有记录');
    }
    if (parts.isNotEmpty) return parts.join(' · ');
    return '完成';
  }
  if (!ok) {
    final error = result['error'] as String? ?? '';
    final stderr = result['stderr'] as String? ?? '';
    if (error.isNotEmpty) return '业务错误: $error';
    if (stderr.isNotEmpty) return '业务错误: ${_firstLine(stderr)}';
    return '业务错误（无错误详情，可展开日志查看）';
  }
  return '';
}

/// 追更检查摘要：逐部给出"新增章节/本地进度/站点不可达"，不再只数新章节数。
List<String> _updateCheckSummary(List reports) {
  final parts = <String>[];
  var newCount = 0;
  var errorCount = 0;
  final details = <String>[];
  for (final report in reports) {
    if (report is! Map<String, dynamic>) continue;
    final news = report['new_chapters'];
    if (news is List) newCount += news.length;
    final error = report['error'];
    if (error is String && error.isNotEmpty) {
      errorCount++;
      // 站点不可达/解析失败必须显式暴露，否则"检查了但没有更新"无法与
      // "根本没检查成功"区分。
      details.add('${report['title'] ?? report['comic_id']}: 站点不可达');
      continue;
    }
    final message = report['message'];
    if (message is String && message.isNotEmpty) {
      details.add('${report['title'] ?? report['comic_id']}: $message');
    }
  }
  parts.add('检查 ${reports.length} 部');
  parts.add(newCount > 0 ? '新增 $newCount 章' : '无新章节');
  if (errorCount > 0) parts.add('$errorCount 部站点不可达');
  if (details.isNotEmpty) parts.add(details.join('；'));
  return parts;
}

/// 下载结果摘要（downloaded/failed/message/未下载提示）。
List<String> _downloadSummary(Map<String, dynamic> data, {String prefix = ''}) {
  final parts = <String>[];
  final downloaded = data['downloaded'];
  final failed = data['failed'];
  if (downloaded is List && downloaded.isNotEmpty) {
    parts.add('$prefix下载成功 ${downloaded.length} 章');
  }
  if (failed is List && failed.isNotEmpty) {
    parts.add('$prefix失败 ${failed.length} 章（已重试一轮）');
    // 给出首个失败原因，避免只报数量让用户无从下手
    final first = failed.first;
    if (first is Map<String, dynamic>) {
      final err = first['error'];
      if (err is String && err.isNotEmpty) {
        parts.add('示例: ${_firstLine(err)}');
      }
    }
  }
  if (downloaded is List &&
      downloaded.isEmpty &&
      (failed is! List || failed.isEmpty)) {
    parts.add('无待下载章节');
  }
  final message = data['message'];
  if (message is String && message.isNotEmpty) {
    parts.add(message);
  }
  return parts;
}

String _firstLine(String text) {
  final index = text.indexOf('\n');
  final line = index >= 0 ? text.substring(0, index) : text;
  return line.length > 160 ? '${line.substring(0, 160)}…' : line;
}

/// 日志文本样式。
const TextStyle comixLogTextStyle = TextStyle(
  fontSize: 11,
  fontFamily: 'monospace',
  color: AppColors.onSurfaceVariant,
);
