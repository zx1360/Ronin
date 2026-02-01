import 'package:flutter/material.dart';
import 'package:torrid/core/constants/spacing.dart';

class GallerySettingPage extends StatelessWidget {
  const GallerySettingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("媒体管理设置")),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("本地存储情况", style: Theme.of(context).textTheme.titleMedium),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.storage),
                    title: const Text("数据库占用:"),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("media_assets: __"),
                        Text("media_tags: __"),
                        Text("media_tag_links: __"),
                      ],
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.folder),
                    title: const Text("文件系统占用:"),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("文件数量: __"),
                        Text("占用大小: __"),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
