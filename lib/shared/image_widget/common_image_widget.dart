import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';

// 对于一个图片路径, 首先在应用本地查找, 不存在则向服务器请求, 失败则展示占位图标.
class CommonImageWidget extends ConsumerWidget {
  final String imageUrl;
  const CommonImageWidget({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.file(
        File(imageUrl),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          final serverUrl = ref.read(apiClientManagerProvider).baseUrl;
          return Image.network(
            "$serverUrl/static/$imageUrl",
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                // 封面占位符
                Container(
                  color: Colors.grey[200],
                  child: const Center(
                    child: Icon(Icons.book, color: Colors.grey, size: 30),
                  ),
                ),
          );
        },
      ),
    );
  }
}
