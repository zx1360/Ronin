import 'package:flutter/material.dart';
import 'package:torrid/core/constants/spacing.dart';

class GallerySettingPage extends StatefulWidget {
  const GallerySettingPage({super.key});

  @override
  State<GallerySettingPage> createState() => _GallerySettingPageState();
}

class _GallerySettingPageState extends State<GallerySettingPage> {
  // PS: TODO: 通过riverpod+Hive持久化设置并共享与不同组件.
  bool isPreviewAllowed = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("媒体管理设置")),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // 基本信息呈现.
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // PS: 数据库及文件系统占用情况.
                  Text(
                    "本地存储情况",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
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
                      children: [Text("文件数量: __"), Text("占用大小: __")],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 功能设置区.
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("功能设置", style: Theme.of(context).textTheme.titleMedium),
                  // TODO: 待考虑.
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("启用预览小窗"),
                    subtitle: const Text("小窗预览下一个媒体文件."),
                    value: isPreviewAllowed,
                    onChanged: (val) {
                      setState(() {
                        isPreviewAllowed = val;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),

          // 数据同步区.
          // 使用'api_client'目录下相关代码进行数据同步操作.
          // 包括传输进度条, 下载时由于需要下载大量媒体文件, 考虑并发下载/中断续传等功能.(但是要保证原子性和数据一致性,即要么显示为全部下载成功,要么全部失败.)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("数据同步", style: Theme.of(context).textTheme.titleMedium),
                  // 获取一批次的媒体文件信息+全量标签记录+相关的文件标签联系数据以及相关的媒体文件+缩略图预览图.
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.sync),
                    title: const Text("下载一批媒体文件."),
                    // 输入下载多少, 默认50个.
                    subtitle: Placeholder(),
                    trailing: ElevatedButton(
                      onPressed: () {},
                      child: const Text("下载"),
                    ),
                    onTap: () {},
                  ),
                  // PS: 获取modified_count变量, 上传媒体文件队列中它和它之前所有media_assets表中记录+全量tags表记录+相关的media_tag_links表记录,然后重置modified_count变量.
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.sync),
                    title: const Text("上传本地数据."),
                    // (只读)三个表中分别涉及到的记录条数.
                    subtitle: Placeholder(),
                    trailing: ElevatedButton(
                      onPressed: () {},
                      child: const Text("上传"),
                    ),
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),

          // 危险操作区.
          // TODO: (清空外部应用私有路径下的"/gallery"文件夹以及清空sqlfite数据库'media_assets','media_tags','media_tag_links'三张表数据)
          // TODO: 确认对话框.
          Card(
            color: Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "危险操作",
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: Colors.red),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.delete_forever,
                      color: Colors.red,
                    ),
                    title: const Text("清空相关sqflite数据表"),
                    subtitle: const Text("删除所有媒体文件及其标签和关联数据"),
                    onTap: () {},
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.folder_delete, color: Colors.red),
                    title: const Text("清空媒体文件夹"),
                    subtitle: const Text(
                      "删除外部应用私有路径下的/gallery/下的所有文件.",
                    ),
                    // 保留目录结构但清空文件.
                    onTap: () {},
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
