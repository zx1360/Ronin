import 'dart:io';

import 'package:flutter/material.dart';
import 'package:torrid/features/others/comic/models/data_class.dart';

class ComicHeader extends StatelessWidget {
  final ComicInfo info;
  const ComicHeader({super.key, required this.info});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 封面图
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: info.coverImage != null
                ? Image.file(
                    File(info.coverImage!),
                    width: 120,
                    height: 180,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 120,
                    height: 180,
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(Icons.book, color: Colors.grey, size: 40),
                    ),
                  ),
          ),

          const SizedBox(width: 16),

          // 漫画信息，使用Expanded避免溢出
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                _buildInfoRow('章节数', '${info.chapterCount} 章'),
                _buildInfoRow('总图片数', '${info.totalImages} 张'),
                _buildInfoRow(
                  '存储路径',
                  info.path.split(Platform.pathSeparator).last,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}