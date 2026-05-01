import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

// TODO: 2. titlebar设为position(), 让各页面内容在ShellPage的Stack内部, 实现内容置顶呈现.
class TitleBar extends StatelessWidget {
  const TitleBar({super.key});

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
          Expanded(
            child: DragToMoveArea(child: Container(height: double.infinity)),
          ),
          IconButton(
            icon: Icon(
              Icons.keyboard_double_arrow_down_sharp,
              color: colorScheme.onSurfaceVariant,
            ),
            onPressed: () {},
            tooltip: '菜单',
            splashRadius: 20,
          ),
          IconButton(
            icon: Icon(Icons.remove, color: colorScheme.onSurfaceVariant),
            onPressed: () => windowManager.minimize(),
            tooltip: '最小化',
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
