import 'package:flutter/material.dart';

import '../models/countdown_timer_model.dart';

/// 单个倒计时器卡片组件
class CountdownTimerCard extends StatelessWidget {
  final CountdownTimerModel timer;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onRestart;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const CountdownTimerCard({
    super.key,
    required this.timer,
    required this.onStart,
    required this.onStop,
    required this.onRestart,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // 背景进度条
            _buildProgressBackground(colorScheme),
            // 内容
            _buildContent(context, colorScheme),
          ],
        ),
      ),
    );
  }

  /// 构建进度背景
  Widget _buildProgressBackground(ColorScheme colorScheme) {
    Color backgroundColor;
    Color progressColor;

    switch (timer.status) {
      case CountdownTimerStatus.idle:
        backgroundColor = colorScheme.surfaceContainerHighest;
        progressColor = colorScheme.surfaceContainerHighest;
        break;
      case CountdownTimerStatus.running:
        backgroundColor = colorScheme.primaryContainer.withValues(alpha: 0.3);
        // 根据进度渐变颜色：绿色 -> 黄色 -> 橙色 -> 红色
        progressColor = _getProgressColor(timer.progressPercentage);
        break;
      case CountdownTimerStatus.completed:
        backgroundColor = colorScheme.errorContainer;
        progressColor = colorScheme.error.withValues(alpha: 0.8);
        break;
    }

    return Container(
      height: 140,
      color: backgroundColor,
      child: timer.isRunning
          ? Stack(
              children: [
                // 已过时间的背景
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: timer.progressPercentage,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          progressColor.withValues(alpha: 0.6),
                          progressColor.withValues(alpha: 0.8),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : null,
    );
  }

  /// 根据进度百分比获取颜色
  Color _getProgressColor(double progress) {
    if (progress < 0.5) {
      // 绿色到黄色
      return Color.lerp(
        const Color(0xFF4CAF50),
        const Color(0xFFFFEB3B),
        progress * 2,
      )!;
    } else if (progress < 0.8) {
      // 黄色到橙色
      return Color.lerp(
        const Color(0xFFFFEB3B),
        const Color(0xFFFF9800),
        (progress - 0.5) / 0.3,
      )!;
    } else {
      // 橙色到红色
      return Color.lerp(
        const Color(0xFFFF9800),
        const Color(0xFFF44336),
        (progress - 0.8) / 0.2,
      )!;
    }
  }

  /// 构建内容
  Widget _buildContent(BuildContext context, ColorScheme colorScheme) {
    return Container(
      height: 140,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    _buildStatusIndicator(colorScheme),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        timer.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              // 操作菜单
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: colorScheme.onSurfaceVariant),
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      onEdit();
                      break;
                    case 'delete':
                      onDelete();
                      break;
                  }
                },
                enabled: timer.isIdle, // 只有空闲状态才能编辑删除
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit),
                        SizedBox(width: 8),
                        Text('编辑'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text('删除', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          // 时间显示
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                timer.formattedRemainingTime,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w300,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: timer.isCompleted
                      ? colorScheme.error
                      : colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '/ ${timer.formattedTotalTime}',
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const Spacer(),
              // 操作按钮
              _buildActionButton(colorScheme),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建状态指示器
  Widget _buildStatusIndicator(ColorScheme colorScheme) {
    Color indicatorColor;
    IconData icon;

    switch (timer.status) {
      case CountdownTimerStatus.idle:
        indicatorColor = colorScheme.outline;
        icon = Icons.timer_outlined;
        break;
      case CountdownTimerStatus.running:
        indicatorColor = const Color(0xFF4CAF50);
        icon = Icons.play_circle_filled;
        break;
      case CountdownTimerStatus.completed:
        indicatorColor = colorScheme.error;
        icon = Icons.check_circle;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: indicatorColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        icon,
        size: 20,
        color: indicatorColor,
      ),
    );
  }

  /// 构建操作按钮
  Widget _buildActionButton(ColorScheme colorScheme) {
    switch (timer.status) {
      case CountdownTimerStatus.idle:
        return FilledButton.icon(
          onPressed: onStart,
          icon: const Icon(Icons.play_arrow),
          label: const Text('开始'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF4CAF50),
            foregroundColor: Colors.white,
          ),
        );
      case CountdownTimerStatus.running:
        return FilledButton.icon(
          onPressed: onStop,
          icon: const Icon(Icons.stop),
          label: const Text('终止'),
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.error,
            foregroundColor: colorScheme.onError,
          ),
        );
      case CountdownTimerStatus.completed:
        return FilledButton.icon(
          onPressed: onRestart,
          icon: const Icon(Icons.refresh),
          label: const Text('重新开始'),
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
          ),
        );
    }
  }
}
