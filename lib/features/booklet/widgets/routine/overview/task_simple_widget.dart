import 'dart:io';

import 'package:flutter/material.dart';
import 'package:torrid/core/services/io/io_service.dart';

/// 任务简洁展示组件
/// 用于 Overview 页面展示任务的基本信息和完成次数
class TaskSimpleWidget extends StatelessWidget {
  const TaskSimpleWidget({
    super.key,
    required this.title,
    required this.description,
    required this.imgUrl,
    this.completionCount,
  });

  final String title;
  final String description;
  final String imgUrl;
  /// 任务完成次数，可选参数
  final int? completionCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      padding: const EdgeInsets.all(8),
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
                        return _buildPlaceholder();
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
                // 标题行：任务标题 + 完成次数徽章
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.yellow.shade800,
                        ),
                      ),
                    ),
                    // 完成次数徽章
                    if (completionCount != null)
                      _buildCompletionBadge(completionCount!),
                  ],
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    description,
                    overflow: TextOverflow.visible,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建图片占位符
  Widget _buildPlaceholder() {
    return Container(
      width: 60,
      height: 60,
      color: Colors.yellow.shade200,
      child: Icon(
        Icons.task,
        color: Colors.yellow.shade700,
      ),
    );
  }

  /// 构建完成次数徽章
  Widget _buildCompletionBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: count > 0 ? Colors.green.shade100 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: count > 0 ? Colors.green.shade400 : Colors.grey.shade400,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 14,
            color: count > 0 ? Colors.green.shade700 : Colors.grey.shade600,
          ),
          const SizedBox(width: 4),
          Text(
            '$count 次',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: count > 0 ? Colors.green.shade700 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}