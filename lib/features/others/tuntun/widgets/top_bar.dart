import 'package:flutter/material.dart';

class TopBar extends StatelessWidget {
  const TopBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        // 顶部安全区域 - 状态栏
        top: true,
        bottom: true,
        child: Container(
          color: Colors.black54, // 半透明黑色背景
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 返回按钮
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 8),

              // TODO: 更多页面, 视频/图片(或者按后缀?), 搜索...
              // 右侧按钮组
              // Row(
              //   children: [

              //   ],
              // ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onPressed: () {
                  // TODO: 更多选项
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
