import 'package:flutter/material.dart';

class BottomBar extends StatelessWidget {
  const BottomBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        color: Colors.cyan,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(
                IconData(0xe63e, fontFamily: "iconfont"),
                color: Colors.white,
                size: 28,
              ),
              onPressed: () {
                // TODO: 打标签功能
              },
            ),
            IconButton(
              icon: const Icon(
                IconData(0xe606, fontFamily: "iconfont"),
                color: Colors.white,
                size: 28,
              ),
              onPressed: () {
                // TODO: 评论功能
              },
            ),
            IconButton(
              icon: const Icon(
                IconData(0xe649, fontFamily: "iconfont"),
                color: Colors.white,
                size: 28,
              ),
              onPressed: () {
                // TODO: 分享功能
              },
            ),
            IconButton(
              icon: const Icon(Icons.download, color: Colors.white, size: 28),
              onPressed: () {
                // TODO: 下载功能
              },
            ),
            // TODO: 下一图片的小窗预览开关, 也许扩展, 弄个"再下一个, 跳至该视频.)
          ],
        ),
      ),
    );
  }
}