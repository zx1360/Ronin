import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class TitleBar extends StatelessWidget {
  /// 窗口是否处于最大化状态；由 ShellPage 监听窗口事件维护。
  final bool isMaximized;

  const TitleBar({super.key, required this.isMaximized});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      height: 48,
      color: Colors.transparent,
      child: Row(
        children: [
          // 双击切换最大化由 DragToMoveArea 自带（window_manager 0.5.x）。
          Expanded(
            child: DragToMoveArea(child: Container(height: double.infinity)),
          ),
          IconButton(
            icon: Icon(Icons.remove, color: colorScheme.onSurfaceVariant),
            onPressed: () => windowManager.minimize(),
            tooltip: '最小化',
            splashRadius: 20,
          ),
          IconButton(
            icon: Icon(
              isMaximized ? Icons.filter_none : Icons.crop_square,
              color: colorScheme.onSurfaceVariant,
            ),
            onPressed: () => isMaximized
                ? windowManager.unmaximize()
                : windowManager.maximize(),
            tooltip: isMaximized ? '向下还原' : '最大化',
            splashRadius: 20,
          ),
          IconButton(
            icon: Icon(Icons.close, color: colorScheme.onSurfaceVariant),
            onPressed: () => windowManager.hide(),
            tooltip: '关闭',
            splashRadius: 20,
          ),
        ],
      ),
    );
  }
}
