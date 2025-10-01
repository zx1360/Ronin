import 'dart:io';

import 'package:flutter/material.dart';
import 'package:torrid/core/services/io/io_service.dart';

class TaskWidget extends StatelessWidget {
  const TaskWidget({
    super.key,
    required this.title,
    required this.description,
    required this.imgUrl,
    this.completed = false,
    required this.switchCB,
  });
  final String title;
  final String description;
  final String imgUrl;
  final bool completed;
  final Function switchCB;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.yellow.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.yellow.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 任务相关图片
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: FutureBuilder<File?>(
              future: IoService.getImageFile(imgUrl),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  if (snapshot.hasData) {
                    return Image.file(
                      snapshot.data!,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 60,
                          height: 60,
                          color: Colors.yellow.shade200,
                          child: Icon(
                            Icons.task,
                            color: Colors.yellow.shade700,
                          ),
                        );
                      },
                    );
                  }
                }
                return Container(
                  width: 60,
                  height: 60,
                  color: Colors.yellow.shade200,
                  child: snapshot.connectionState == ConnectionState.waiting
                      ? const CircularProgressIndicator(strokeWidth: 2)
                      : Icon(Icons.task, color: Colors.yellow.shade700),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          // 任务标题和描述等信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.yellow.shade800,
                    decoration: completed ? TextDecoration.lineThrough : null,
                    decorationThickness: 2.5,
                    decorationColor: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 14,
                    decoration: completed ? TextDecoration.lineThrough : null,
                    decorationThickness: 2.0,
                    decorationColor: Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),
          // 完成状态切换按钮
          Transform.scale(
            scale: 1.2,
            child: Checkbox(
              value: completed,
              onChanged: (value) {
                switchCB(value);
              },
              activeColor: Colors.yellow.shade600,
              checkColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
