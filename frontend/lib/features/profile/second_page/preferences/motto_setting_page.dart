import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:torrid/app/theme/theme_book.dart';
import 'package:torrid/core/constants/spacing.dart';
import 'package:torrid/providers/personalization/personalization_providers.dart';

/// 座右铭设置页面
class MottoSettingPage extends ConsumerStatefulWidget {
  const MottoSettingPage({super.key});

  @override
  ConsumerState<MottoSettingPage> createState() => _MottoSettingPageState();
}

class _MottoSettingPageState extends ConsumerState<MottoSettingPage> {
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final mottos = settings.mottos;

    return Scaffold(
      appBar: AppBar(
        title: const Text('座右铭设置'),
        actions: [
          IconButton(
            onPressed: _showAddDialog,
            icon: const Icon(Icons.add),
            tooltip: '添加座右铭',
          ),
        ],
      ),
      body: mottos.isEmpty
          ? _buildEmptyState()
          : _buildMottoList(mottos),
    );
  }

  /// 空状态
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.format_quote_outlined,
            size: 80,
            color: AppTheme.outline,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '暂无座右铭',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton.icon(
            onPressed: _showAddDialog,
            icon: const Icon(Icons.add),
            label: const Text('添加座右铭'),
          ),
        ],
      ),
    );
  }

  /// 座右铭列表
  Widget _buildMottoList(List<String> mottos) {
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: mottos.length,
      itemBuilder: (context, index) {
        return _buildMottoCard(mottos[index], index, mottos.length);
      },
    );
  }

  /// 座右铭卡片
  Widget _buildMottoCard(String motto, int index, int total) {
    final isOnlyOne = total == 1;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: () => _showEditDialog(index, motto),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 引号图标
              Icon(
                Icons.format_quote,
                color: AppTheme.primary,
                size: 24,
              ),
              const SizedBox(width: AppSpacing.sm),
              // 座右铭文本
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      motto,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                    if (total > 1) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '${index + 1} / $total',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.outline,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // 操作按钮
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    _showEditDialog(index, motto);
                  } else if (value == 'delete') {
                    _confirmDelete(index, isOnlyOne);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 20),
                        SizedBox(width: 8),
                        Text('编辑'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    enabled: !isOnlyOne,
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline,
                          size: 20,
                          color: isOnlyOne ? Colors.grey : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '删除',
                          style: TextStyle(
                            color: isOnlyOne ? Colors.grey : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 显示添加对话框
  Future<void> _showAddDialog() async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('添加座右铭'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          maxLength: 100,
          decoration: const InputDecoration(
            hintText: '输入你的座右铭...',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                Navigator.pop(dialogContext, text);
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );

    // 延迟 dispose，确保对话框完全关闭
    final savedResult = result;
    Future.delayed(const Duration(milliseconds: 500), () {
      controller.dispose();
    });

    if (savedResult != null && savedResult.isNotEmpty) {
      await ref.read(appSettingsProvider.notifier).addMotto(savedResult);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('座右铭添加成功')),
        );
      }
    }
  }

  /// 显示编辑对话框
  Future<void> _showEditDialog(int index, String currentMotto) async {
    final controller = TextEditingController(text: currentMotto);

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('编辑座右铭'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          maxLength: 100,
          decoration: const InputDecoration(
            hintText: '输入你的座右铭...',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                Navigator.pop(dialogContext, text);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );

    // 延迟 dispose，确保对话框完全关闭
    final savedResult = result;
    Future.delayed(const Duration(milliseconds: 500), () {
      controller.dispose();
    });

    if (savedResult != null && savedResult.isNotEmpty && savedResult != currentMotto) {
      await ref.read(appSettingsProvider.notifier).updateMotto(index, savedResult);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('座右铭更新成功')),
        );
      }
    }
  }

  /// 确认删除
  Future<void> _confirmDelete(int index, bool isOnlyOne) async {
    if (isOnlyOne) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('至少需要保留一条座右铭')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这条座右铭吗？'),
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
      await ref.read(appSettingsProvider.notifier).removeMotto(index);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('删除成功')),
        );
      }
    }
  }
}
