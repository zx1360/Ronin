import 'package:flutter/material.dart';
import 'package:torrid/features/others/comic/services/comic_servic.dart';

class TopControllBar extends StatelessWidget {
  final String comicName;
  final String chapterName;
  final int currentNum;
  final int totalNum;
  final bool? isMerging;
  final VoidCallback? saveFunc;
  final IconData primaryIcon;
  final Color? primaryIconColor;
  final String? primaryTooltip;
  final VoidCallback? secondarySaveFunc;
  final IconData? secondaryIcon;
  final Color? secondaryIconColor;
  final String? secondaryTooltip;

  const TopControllBar({
    super.key,
    required this.comicName,
    required this.chapterName,
    required this.currentNum,
    required this.totalNum,
    required this.saveFunc,
    this.isMerging,
    this.primaryIcon = Icons.save_alt_rounded,
    this.primaryIconColor,
    this.primaryTooltip,
    this.secondarySaveFunc,
    this.secondaryIcon,
    this.secondaryIconColor,
    this.secondaryTooltip,
  });

  @override
  Widget build(BuildContext context) {
    final name = chapterName.isEmpty ? "" : getChapterTitle(chapterName);
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top,
          left: 16,
          right: 16,
          bottom: 16,
        ),
        color: Colors.black54,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 返回按钮
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),

            // 标题信息
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    comicName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '$name (${currentNum + 1}/$totalNum)',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // 保存当前图片按钮
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (secondarySaveFunc != null && secondaryIcon != null)
                  IconButton(
                    tooltip: secondaryTooltip,
                    icon: Icon(
                      secondaryIcon,
                      color: isMerging ?? false
                          ? Colors.grey
                          : (secondaryIconColor ?? Colors.white),
                    ),
                    onPressed: () {
                      if (isMerging ?? false) return;
                      secondarySaveFunc!();
                    },
                  ),
                if (saveFunc != null)
                  IconButton(
                    tooltip: primaryTooltip,
                    icon: Icon(
                      primaryIcon,
                      color: isMerging ?? false
                          ? Colors.grey
                          : (primaryIconColor ?? Colors.white),
                    ),
                    onPressed: () {
                      if (isMerging ?? false) return;
                      saveFunc!();
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
