import 'package:flutter/material.dart';
import 'package:torrid/app/theme_light.dart';

// 按钮数据模型（保持简洁，新增const构造优化性能）
class ButtonInfo {
  final String name;
  final IconData icon;
  final String route;

  // 新增const构造，支持编译期常量优化
  const ButtonInfo({
    required this.name,
    required this.icon,
    required this.route,
  });
}

// 菜单按钮组件（与全局主题深度绑定，优化交互反馈）
class MenuButton extends StatelessWidget {
  final ButtonInfo info;
  final Function(String route) func; // 明确参数类型，提升代码可读性
  final Color? textColor;
  final Color? highlightColor;

  const MenuButton({
    super.key,
    required this.info,
    required this.func,
    this.textColor,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    // 从主题获取默认值，确保风格统一
    final theme = Theme.of(context);
    final defaultTextColor = textColor ?? AppTheme.darkTextColor;
    final defaultHighlightColor =
        highlightColor ??
        AppTheme.primaryColorLight.withOpacity(0.2); // 替代过时的withValues

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => func(info.route),
        splashColor: AppTheme.primaryColor.withOpacity(0.2),
        highlightColor: defaultHighlightColor,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          height: 58,
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: defaultTextColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  info.icon,
                  color: defaultTextColor.withOpacity(0.9),
                  size: 22,
                ),
              ),
              const SizedBox(width: 18),
              Text(
                info.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: defaultTextColor,
                  fontSize: 16.5,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
