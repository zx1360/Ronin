import 'package:flutter/material.dart';
import 'package:torrid/shared/widgets/file_img_builder.dart';

// 双击任务大图展示
void showBigScaledImage(BuildContext context, String path) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    isScrollControlled: true,

    builder: (context) {
      // 定义本弹出页的最大高度和最小宽度.
      final maxHeight = MediaQuery.of(context).size.height * 0.85;
      final minWidth = MediaQuery.of(context).size.width;
      return Container(
        constraints: BoxConstraints(maxHeight: maxHeight, minWidth: minWidth),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8.0),
          child: FileImageBuilder(relativeImagePath: path, isOriginScale: true,),
        ),
      );
    },
  );
}
