import 'package:flutter/material.dart';
import 'package:torrid/core/models/mood.dart';

/// 心情选择器组件 - 通用组件，可在打卡和随笔页面复用
class MoodSelector extends StatelessWidget {
  /// 当前选中的心情（可为空）
  final MoodType? selectedMood;
  
  /// 心情变化回调
  final ValueChanged<MoodType?> onMoodChanged;
  
  /// 是否为紧凑模式（只显示图标，不显示文字）
  final bool compact;
  
  /// 图标大小
  final double iconSize;

  const MoodSelector({
    super.key,
    required this.selectedMood,
    required this.onMoodChanged,
    this.compact = false,
    this.iconSize = 28,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: MoodType.values.map((mood) {
        final isSelected = selectedMood == mood;
        return GestureDetector(
          onTap: () {
            // 点击已选中的心情则取消选择
            if (isSelected) {
              onMoodChanged(null);
            } else {
              onMoodChanged(mood);
            }
          },
          child: Tooltip(
            message: mood.description,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.symmetric(horizontal: compact ? 4 : 6),
              padding: EdgeInsets.all(compact ? 6 : 8),
              decoration: BoxDecoration(
                color: isSelected 
                    ? mood.color.withAlpha(51)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(compact ? 8 : 12),
                border: isSelected 
                    ? Border.all(color: mood.color, width: 2)
                    : null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    mood.emoji,
                    style: TextStyle(fontSize: iconSize),
                  ),
                  if (!compact) ...[
                    const SizedBox(height: 4),
                    Text(
                      mood.label,
                      style: TextStyle(
                        fontSize: 10,
                        color: isSelected ? mood.color : Colors.grey[500],
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// 心情显示组件 - 只读显示心情图标
class MoodDisplay extends StatelessWidget {
  /// 要显示的心情（可为空）
  final MoodType? mood;
  
  /// 图标大小
  final double iconSize;
  
  /// 是否显示文字标签
  final bool showLabel;

  const MoodDisplay({
    super.key,
    required this.mood,
    this.iconSize = 20,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    if (mood == null) {
      return const SizedBox.shrink();
    }
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          mood!.emoji,
          style: TextStyle(fontSize: iconSize),
        ),
        if (showLabel) ...[
          const SizedBox(width: 4),
          Text(
            mood!.label,
            style: TextStyle(
              fontSize: 12,
              color: mood!.color,
            ),
          ),
        ],
      ],
    );
  }
}
