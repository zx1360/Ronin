import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:northstar/application/ops/providers/core_services_provider.dart';
import 'package:northstar/application/ops/providers/ops_settings_provider.dart';
import 'package:northstar/app/theme.dart';
import 'package:northstar/shared/widgets/heading/heading.dart';
import 'package:path/path.dart' as p;

class ComicsPage extends ConsumerStatefulWidget {
  const ComicsPage({super.key});

  @override
  ConsumerState<ComicsPage> createState() => _ComicsPageState();
}

class _ComicsPageState extends ConsumerState<ComicsPage> {
  List<Map<String, dynamic>>? _comics;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadComics();
  }

  Future<void> _loadComics() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final settings = ref.read(opsSettingsControllerProvider);
      final client = ref.read(opsApiClientProvider);
      final comics = await client.fetchComics(settings);
      if (mounted) {
        setState(() {
          _comics = comics;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _togglePublic(String comicId, bool current) async {
    final settings = ref.read(opsSettingsControllerProvider);
    final client = ref.read(opsApiClientProvider);
    try {
      await client.updateComic(settings, comicId, {'is_public': !current});
      await _loadComics();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新失败: $e')),
        );
      }
    }
  }

  Future<void> _deleteComic(String comicId, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除漫画'),
        content: Text('确认删除 "$title" 吗？\n\n这将同时删除数据库记录和文件系统中的漫画资源，不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final settings = ref.read(opsSettingsControllerProvider);
      final client = ref.read(opsApiClientProvider);
      await client.deleteComic(settings, comicId);
      await _loadComics();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"$title" 已删除')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
    }
  }

  Future<void> _replaceCover(String comicId, String title) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return;

    final pickedFile = result.files.first;
    if (pickedFile.path == null) return;

    // 将封面图复制到 static/comics/[title]/ 目录下
    // cover_image 字段存储相对路径
    final coverFileName = 'cover${p.extension(pickedFile.path!)}';
    final targetDir = p.join('static', 'comics', title);
    final targetPath = p.join(targetDir, coverFileName);
    final relativePath = p.join('comics', title, coverFileName).replaceAll('\\', '/');

    try {
      final dir = Directory(targetDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      await File(pickedFile.path!).copy(targetPath);

      // 更新数据库中的 cover_image
      final settings = ref.read(opsSettingsControllerProvider);
      final client = ref.read(opsApiClientProvider);
      await client.updateComic(settings, comicId, {'cover_image': relativePath});

      await _loadComics();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('封面已更新')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('封面替换失败: $e')),
        );
      }
    }
  }

  String _coverUrl(String? coverImage) {
    if (coverImage == null || coverImage.isEmpty) return '';
    final settings = ref.read(opsSettingsControllerProvider);
    final base = settings.apiBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    return '$base/static/$coverImage';
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Heading(title: '漫画资源'),
          TabBar(
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(text: '漫画管理'),
              Tab(text: '连载追踪'),
            ],
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('加载失败: $_error',
                                style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .error)),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _loadComics,
                              icon: const Icon(Icons.refresh),
                              label: const Text('重试'),
                            ),
                          ],
                        ),
                      )
                    : TabBarView(
                        children: [
                          _buildContent(),
                          _TrackingSection(),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final comics = _comics;
    if (comics == null || comics.isEmpty) {
      return const Center(child: Text('暂无漫画资源'));
    }

    return Column(
      children: [
        // 工具栏
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.paddingL, vertical: 8),
          child: Row(
            children: [
              ElevatedButton.icon(
                onPressed: _loadComics,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('刷新'),
              ),
              const SizedBox(width: 12),
              Text('共 ${comics.length} 本漫画', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),

        const Divider(height: 1),

        // 漫画管理列表
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(AppDimens.paddingL),
            itemCount: comics.length,
            itemBuilder: (context, index) {
              return _ComicCard(
                comic: comics[index],
                coverUrl: _coverUrl(comics[index]['cover_image'] as String?),
                onTogglePublic: () => _togglePublic(
                  comics[index]['id'] as String,
                  comics[index]['is_public'] as bool? ?? true,
                ),
                onDelete: () => _deleteComic(
                  comics[index]['id'] as String,
                  comics[index]['title'] as String? ?? '',
                ),
                onReplaceCover: () => _replaceCover(
                  comics[index]['id'] as String,
                  comics[index]['title'] as String? ?? '',
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ComicCard extends StatelessWidget {
  final Map<String, dynamic> comic;
  final String coverUrl;
  final VoidCallback onTogglePublic;
  final VoidCallback onDelete;
  final VoidCallback onReplaceCover;

  const _ComicCard({
    required this.comic,
    required this.coverUrl,
    required this.onTogglePublic,
    required this.onDelete,
    required this.onReplaceCover,
  });

  @override
  Widget build(BuildContext context) {
    final title = comic['title'] as String? ?? '';
    final isPublic = comic['is_public'] as bool? ?? true;
    final readed = comic['readed'] as bool? ?? false;
    final chapterCount = comic['chapter_count'] as int? ?? 0;
    final imageCount = comic['image_count'] as int? ?? 0;
    final source = comic['source'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: AppDimens.spacingM),
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.paddingM),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 封面缩略图
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 72,
                height: 100,
                child: coverUrl.isNotEmpty
                    ? Image.network(
                        coverUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.broken_image, color: Colors.grey),
                        ),
                      )
                    : Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.menu_book, color: Colors.grey),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            // 信息区
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _InfoChip(label: '$chapterCount 章'),
                      _InfoChip(label: '$imageCount 图'),
                      Chip(
                        label: Text(
                          isPublic ? '公开' : '隐藏',
                          style: TextStyle(fontSize: 11, color: isPublic ? Colors.green : Colors.orange),
                        ),
                        backgroundColor: (isPublic ? Colors.green : Colors.orange).withValues(alpha: 0.1),
                        visualDensity: VisualDensity.compact,
                      ),
                      if (readed)
                        Chip(
                          label: const Text('已读', style: TextStyle(fontSize: 11, color: Colors.blue)),
                          backgroundColor: Colors.blue.withValues(alpha: 0.1),
                          visualDensity: VisualDensity.compact,
                        ),
                      if (source.isNotEmpty)
                        Chip(
                          label: Text(source, style: const TextStyle(fontSize: 11)),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            // 操作按钮
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: '替换封面',
                  onPressed: onReplaceCover,
                  icon: const Icon(Icons.photo_library_outlined, size: 20),
                ),
                Switch(
                  value: isPublic,
                  onChanged: (_) => onTogglePublic(),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                IconButton(
                  tooltip: '删除漫画',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  const _InfoChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      visualDensity: VisualDensity.compact,
      backgroundColor: Colors.grey.withValues(alpha: 0.1),
    );
  }
}

class _TrackingSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: AppDimens.spacingL),
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.paddingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('漫画连载追踪', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('即将推出...', style: TextStyle(color: Colors.grey)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
