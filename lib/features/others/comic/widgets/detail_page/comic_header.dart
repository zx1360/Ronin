import 'dart:io';

import 'package:flutter/material.dart';
import 'package:torrid/features/others/comic/models/comic_info.dart';

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
            child: Image.file(
                    File(info.coverImage),
                    width: 120,
                    height: 180,
                    fit: BoxFit.cover,
                  )
          ),

          const SizedBox(width: 16),

          // 漫画信息，使用Expanded避免溢出
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.comicName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                _buildInfoRow('章节数', '${info.chapterCount} 章'),
                _buildInfoRow('总图片数', '${info.imageCount} 张'),
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