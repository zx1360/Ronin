import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:northstar/core/providers/ops/core_services_provider.dart';
import 'package:northstar/core/providers/ops/ops_settings_provider.dart';
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

  /// 就地更新某个漫画的字段，避免全量刷新导致滚动回顶。
  void _patchComic(String comicId, Map<String, dynamic> fields) {
    final list = _comics;
    if (list == null) return;
    final idx = list.indexWhere((c) => c['id'] == comicId);
    if (idx == -1) return;
    final updated = Map<String, dynamic>.from(list[idx]);
    updated.addAll(fields);
    setState(() {
      list[idx] = updated;
    });
  }

  Future<void> _togglePublic(String comicId, bool current) async {
    final settings = ref.read(opsSettingsControllerProvider);
    final client = ref.read(opsApiClientProvider);
    try {
      await client.updateComic(settings, comicId, {'is_public': !current});
      _patchComic(comicId, {'is_public': !current});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('更新失败: $e')));
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
      if (mounted) {
        setState(() {
          _comics?.removeWhere((c) => c['id'] == comicId);
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('"$title" 已删除')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('删除失败: $e')));
      }
    }
  }

  Future<void> _toggleReaded(String comicId, bool current) async {
    final settings = ref.read(opsSettingsControllerProvider);
    final client = ref.read(opsApiClientProvider);
    try {
      await client.updateComic(settings, comicId, {'readed': !current});
      _patchComic(comicId, {'readed': !current});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('更新失败: $e')));
      }
    }
  }

  Future<void> _replaceCover(String comicId, String title) async {
    // 尝试多个候选路径找到静态资源根目录（相对于后端根目录）
    String resolveStaticRoot() {
      final candidates = [
        Directory.current.path,
        p.dirname(Directory.current.path),
        p.dirname(p.dirname(Directory.current.path)),
      ];
      for (final candidate in candidates) {
        if (Directory(p.join(candidate, 'static')).existsSync()) {
          return candidate;
        }
      }
      return Directory.current.path; // 回退
    }

    final staticRoot = resolveStaticRoot();
    final comicDir = p.join(staticRoot, 'static', 'comics', title);
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      initialDirectory: Directory(comicDir).existsSync() ? comicDir : null,
    );

    if (result == null || result.files.isEmpty) return;

    final pickedFile = result.files.first;
    if (pickedFile.path == null) return;

    // 将封面图复制到 static/comics/[title]/ 目录下
    // cover_image 字段存储相对路径
    final coverFileName = 'cover${p.extension(pickedFile.path!)}';
    final targetDir = p.join(staticRoot, 'static', 'comics', title);
    final targetPath = p.join(targetDir, coverFileName);
    final relativePath = p
        .join('comics', title, coverFileName)
        .replaceAll('\\', '/');

    try {
      final dir = Directory(targetDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      await File(pickedFile.path!).copy(targetPath);

      // 更新数据库中的 cover_image
      final settings = ref.read(opsSettingsControllerProvider);
      final client = ref.read(opsApiClientProvider);
      await client.updateComic(settings, comicId, {
        'cover_image': relativePath,
      });

      _patchComic(comicId, {'cover_image': relativePath});
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('封面已更新')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('封面替换失败: $e')));
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
                        Text(
                          '加载失败: $_error',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _loadComics,
                          icon: const Icon(Icons.refresh),
                          label: const Text('重试'),
                        ),
                      ],
                    ),
                  )
                : TabBarView(children: [_buildContent(), _TrackingSection()]),
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
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.paddingM,
            vertical: 6,
          ),
          child: Row(
            children: [
              ElevatedButton.icon(
                onPressed: _loadComics,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('刷新'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '共 ${comics.length} 本漫画',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        // 漫画管理网格
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(AppDimens.paddingS),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 0.58,
              crossAxisSpacing: AppDimens.spacingS,
              mainAxisSpacing: AppDimens.spacingS,
            ),
            itemCount: comics.length,
            itemBuilder: (context, index) {
              final comic = comics[index];
              final id = comic['id'] as String? ?? '$index';
              return _ComicCard(
                key: ValueKey(id),
                comic: comic,
                coverUrl: _coverUrl(comic['cover_image'] as String?),
                onTogglePublic: () =>
                    _togglePublic(id, comic['is_public'] as bool? ?? true),
                onToggleReaded: () =>
                    _toggleReaded(id, comic['readed'] as bool? ?? false),
                onDelete: () =>
                    _deleteComic(id, comic['title'] as String? ?? ''),
                onReplaceCover: () =>
                    _replaceCover(id, comic['title'] as String? ?? ''),
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
  final VoidCallback onToggleReaded;
  final VoidCallback onDelete;
  final VoidCallback onReplaceCover;

  const _ComicCard({
    super.key,
    required this.comic,
    required this.coverUrl,
    required this.onTogglePublic,
    required this.onToggleReaded,
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

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 封面区
          Expanded(
            flex: 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                coverUrl.isNotEmpty
                    ? Image.network(
                        coverUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey[800],
                          child: const Icon(
                            Icons.broken_image,
                            color: Colors.grey,
                            size: 18,
                          ),
                        ),
                      )
                    : Container(
                        color: Colors.grey[800],
                        child: const Icon(
                          Icons.menu_book,
                          color: Colors.grey,
                          size: 18,
                        ),
                      ),
                // 已读标记
                Positioned(
                  top: 2,
                  right: 2,
                  child: InkWell(
                    onTap: onToggleReaded,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        readed ? Icons.done_all : Icons.done,
                        size: 13,
                        color: readed ? Colors.greenAccent : Colors.grey,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 信息区
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 1),
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Wrap(
              spacing: 2,
              runSpacing: 1,
              children: [
                _CompactChip(label: '$chapterCount 章'),
                _CompactChip(label: '$imageCount 图'),
                _CompactChip(
                  label: isPublic ? '公开' : '隐藏',
                  color: isPublic ? Colors.green : Colors.orange,
                ),
                if (readed) const _CompactChip(label: '已读', color: Colors.blue),
              ],
            ),
          ),
          // 操作按钮
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _MiniIconButton(
                  tooltip: '替换封面',
                  onPressed: onReplaceCover,
                  icon: Icons.photo_library_outlined,
                ),
                _MiniIconButton(
                  tooltip: isPublic ? '设为隐藏' : '设为公开',
                  onPressed: onTogglePublic,
                  icon: isPublic ? Icons.visibility : Icons.visibility_off,
                ),
                _MiniIconButton(
                  tooltip: '删除',
                  onPressed: onDelete,
                  icon: Icons.delete_outline,
                  color: Colors.red,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniIconButton extends StatelessWidget {
  final String tooltip;
  final VoidCallback onPressed;
  final IconData icon;
  final Color? color;
  const _MiniIconButton({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 15, color: color),
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
      padding: EdgeInsets.zero,
    );
  }
}

class _CompactChip extends StatelessWidget {
  final String label;
  final Color? color;
  const _CompactChip({required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(label, style: TextStyle(fontSize: 9, color: effectiveColor)),
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
