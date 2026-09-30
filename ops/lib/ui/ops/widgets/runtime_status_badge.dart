import 'package:flutter/material.dart';
import 'package:northstar/domain/ops/models/runtime_process_state.dart';

class RuntimeStatusBadge extends StatelessWidget {
  final RuntimeStatus status;

  const RuntimeStatusBadge({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status, context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Text(
        _statusText(status),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  Color _statusColor(RuntimeStatus status, BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    switch (status) {
      case RuntimeStatus.idle:
        return colors.onSurfaceVariant;
      case RuntimeStatus.starting:
        return colors.secondary;
      case RuntimeStatus.running:
        return Colors.greenAccent.shade400;
      case RuntimeStatus.stopping:
        return Colors.orangeAccent;
      case RuntimeStatus.stopped:
        return colors.tertiary;
      case RuntimeStatus.failed:
        return colors.error;
    }
  }

  String _statusText(RuntimeStatus status) {
    switch (status) {
      case RuntimeStatus.idle:
        return '空闲';
      case RuntimeStatus.starting:
        return '启动中';
      case RuntimeStatus.running:
        return '运行中';
      case RuntimeStatus.stopping:
        return '停止中';
      case RuntimeStatus.stopped:
        return '已停止';
      case RuntimeStatus.failed:
        return '失败';
    }
  }
}
