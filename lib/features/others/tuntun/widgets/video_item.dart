import 'package:flutter/material.dart';
import 'package:torrid/features/others/tuntun/models/data_class.dart';

class VideoItem extends StatelessWidget {
  final VideoData video;
  const VideoItem({super.key, required this.video});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // TODO: 后续可于视频之上层叠其他组件.
        Center(
          child: AspectRatio(
            aspectRatio: 9 / 16, // 常见视频比例
            child: Container(
              color: Colors.black,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.play_circle_outline,
                      size: 64,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      video.title,
                      style: const TextStyle(color: Colors.white, fontSize: 24),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '点击播放视频',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}