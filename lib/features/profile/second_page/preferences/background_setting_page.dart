import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'package:torrid/app/theme/theme_book.dart';
import 'package:torrid/core/constants/spacing.dart';
import 'package:torrid/providers/personalization/personalization_providers.dart';

/// 图片类型枚举
enum ImageCategory {
  background,
  sidebar,
}

/// 背景图片设置页面
/// 管理背景图和侧边栏图
class BackgroundSettingPage extends ConsumerStatefulWidget {
  const BackgroundSettingPage({super.key});

  @override
  ConsumerState<BackgroundSettingPage> createState() => _BackgroundSettingPageState();
}

class _BackgroundSettingPageState extends ConsumerState<BackgroundSettingPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ImagePicker _picker = ImagePicker();
  final Uuid _uuid = const Uuid();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('背景图片设置'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '主页背景'),
            Tab(text: '侧边栏背景'),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              _buildImageGrid(ImageCategory.background),
              _buildImageGrid(ImageCategory.sidebar),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isLoading ? null : _pickAndAddImage,
        child: const Icon(Icons.add_photo_alternate),
      ),
    );
  }

  /// 构建图片网格
  Widget _buildImageGrid(ImageCategory category) {
    final imagesAsync = category == ImageCategory.background
        ? ref.watch(backgroundImagesProvider)
        : ref.watch(sidebarImagesProvider);

    final settings = ref.watch(appSettingsProvider);
    final paths = category == ImageCategory.background
        ? settings.backgroundImages
        : settings.sidebarImages;

    return imagesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: AppSpacing.sm),
            Text('加载失败: $error'),
          ],
        ),
      ),
      data: (files) {
        if (files.isEmpty) {
          return _buildEmptyState(category);
        }

        // 单张图片时直接显示
        if (files.length == 1) {
          return _buildSingleImage(files.first, paths.first, category);
        }

        // 多张图片时显示网格
        return GridView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: AppSpacing.sm,
            mainAxisSpacing: AppSpacing.sm,
            childAspectRatio: 0.75,
          ),
          itemCount: files.length,
          itemBuilder: (context, index) {
            final file = files[index];
            final relativePath = paths.length > index ? paths[index] : '';
            return _buildImageCard(file, relativePath, category);
          },
        );
      },
    );
  }

  /// 空状态
  Widget _buildEmptyState(ImageCategory category) {
    final title = category == ImageCategory.background ? '主页背景' : '侧边栏背景';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_outlined,
            size: 80,
            color: AppTheme.outline,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '暂无$title图片',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '点击右下角按钮添加图片',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.outline,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton.icon(
            onPressed: _pickAndAddImage,
            icon: const Icon(Icons.add),
            label: const Text('添加图片'),
          ),
        ],
      ),
    );
  }

  /// 单张图片显示
  Widget _buildSingleImage(File file, String relativePath, ImageCategory category) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(
                    file,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppTheme.surfaceContainerHighest,
                      child: const Icon(Icons.broken_image, size: 48),
                    ),
                  ),
                  Positioned(
                    top: AppSpacing.sm,
                    right: AppSpacing.sm,
                    child: _buildDeleteButton(relativePath, category),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '当前使用此图片作为背景',
            style: TextStyle(
              color: AppTheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建图片卡片
  Widget _buildImageCard(File file, String relativePath, ImageCategory category) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 图片
          Image.file(
            file,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: AppTheme.surfaceContainerHighest,
              child: const Icon(Icons.broken_image, size: 48),
            ),
          ),
          // 删除按钮
          Positioned(
            top: AppSpacing.xs,
            right: AppSpacing.xs,
            child: _buildDeleteButton(relativePath, category),
          ),
          // 文件名
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withAlpha(150),
                  ],
                ),
              ),
              child: Text(
                p.basename(file.path),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 删除按钮
  Widget _buildDeleteButton(String relativePath, ImageCategory category) {
    return Material(
      color: Colors.black45,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _confirmDelete(relativePath, category),
        child: const Padding(
          padding: EdgeInsets.all(6),
          child: Icon(
            Icons.delete_outline,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }

  /// 选择并添加图片（支持多选）
  Future<void> _pickAndAddImage() async {
    final category = _tabController.index == 0
        ? ImageCategory.background
        : ImageCategory.sidebar;

    try {
      final List<XFile> pickedList = await _picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (pickedList.isEmpty) return;

      setState(() => _isLoading = true);

      final notifier = ref.read(appSettingsProvider.notifier);
      int successCount = 0;
      int failCount = 0;

      for (final picked in pickedList) {
        final bytes = await picked.readAsBytes();
        final ext = p.extension(picked.path).toLowerCase();
        final fileName = '${_uuid.v4()}$ext';

        bool success;
        if (category == ImageCategory.background) {
          success = await notifier.addBackgroundImage(bytes, fileName);
        } else {
          success = await notifier.addSidebarImage(bytes, fileName);
        }

        if (success) {
          successCount++;
        } else {
          failCount++;
        }
      }

      if (mounted) {
        setState(() => _isLoading = false);
        String message;
        if (failCount == 0) {
          message = '成功添加 $successCount 张图片';
        } else if (successCount == 0) {
          message = '图片添加失败';
        } else {
          message = '添加 $successCount 张成功，$failCount 张失败';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    }
  }

  /// 确认删除
  Future<void> _confirmDelete(String relativePath, ImageCategory category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这张图片吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);

      final notifier = ref.read(appSettingsProvider.notifier);
      bool success;

      if (category == ImageCategory.background) {
        success = await notifier.removeBackgroundImage(relativePath);
      } else {
        success = await notifier.removeSidebarImage(relativePath);
      }

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(success ? '删除成功' : '删除失败')),
        );
      }
    }
  }
}
