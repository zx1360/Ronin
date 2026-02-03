import 'package:flutter/material.dart';

/// PS: 媒体文件网格视图组件, 呈现图片/视频的缩略图(对应媒体文件数据thumb_path字段的图片.)
/// 初始一行四个, 可上下滚动. 放大/缩小手势改变每行数量, 每行个数的可能值: 3, 4, 8, 16.
/// 长按进入选择模式, 可多选. 并对选中的进行捆绑分组(以第一个选中的为主文件)或者一并删除操作.
class MediasGridView extends StatelessWidget {
  const MediasGridView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}