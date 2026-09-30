import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/app/theme/theme_book.dart';
import 'package:torrid/features/ai/models/ai_search_models.dart';
import 'package:torrid/features/immich/providers/immich_providers.dart';

/// AI 标签筛选面板（底部弹出）。
///
/// 与人工标签的筛选体验对齐：可搜索、按出现次数排序、点击即切换选中（多选累积）。
/// 只读数据——AI 标签由服务端 VLM 生成，这里仅用于筛选，不写服务端。
Future<void> showImmichAiTagSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const FractionallySizedBox(
      heightFactor: 0.75,
      child: _AiTagSheet(),
    ),
  );
}

class _AiTagSheet extends ConsumerStatefulWidget {
  const _AiTagSheet();

  @override
  ConsumerState<_AiTagSheet> createState() => _AiTagSheetState();
}

class _AiTagSheetState extends ConsumerState<_AiTagSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tagsAsync = ref.watch(immichAiTagsProvider);
    final filter = ref.watch(immichFilterNotifierProvider);
    final notifier = ref.read(immichFilterNotifierProvider.notifier);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome, size: 16, color: Colors.teal),
              const SizedBox(width: 6),
              Text('AI 标签', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(width: 6),
              Text(
                '只读 · 与人工标签独立',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
              const Spacer(),
              if (filter.vlmTags.isNotEmpty)
                TextButton(
                  onPressed: notifier.clearVlmTags,
                  child: Text('清空 (${filter.vlmTags.length})'),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('完成'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value.trim()),
            decoration: InputDecoration(
              hintText: '搜索 AI 标签',
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    ),
              isDense: true,
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: tagsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('读取失败: $error')),
            data: (all) => _buildList(all, filter, notifier),
          ),
        ),
      ],
    );
  }

  Widget _buildList(
    List<AiTagCount> all,
    ImmichFilter filter,
    ImmichFilterNotifier notifier,
  ) {
    if (all.isEmpty) {
      return const Center(
        child: Text(
          '暂无 AI 标签\n（需要服务端 VLM 标注产出）',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.onSurfaceVariant),
        ),
      );
    }

    final selected = filter.vlmTags;
    // 已选置顶，其余按出现次数降序：常用标签一眼可见
    final query = _query.toLowerCase();
    final visible = [
      for (final item in all)
        if (query.isEmpty || item.tag.toLowerCase().contains(query)) item,
    ]..sort((a, b) {
        final aSelected = selected.contains(a.tag);
        final bSelected = selected.contains(b.tag);
        if (aSelected != bSelected) return aSelected ? -1 : 1;
        if (a.count != b.count) return b.count - a.count;
        return a.tag.compareTo(b.tag);
      });

    if (visible.isEmpty) {
      return const Center(child: Text('没有匹配的标签'));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: visible.length,
      itemBuilder: (context, index) {
        final item = visible[index];
        final isSelected = selected.contains(item.tag);
        return CheckboxListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          controlAffinity: ListTileControlAffinity.leading,
          value: isSelected,
          onChanged: (_) => notifier.toggleVlmTag(item.tag),
          title: Text(item.tag, style: const TextStyle(fontSize: 14)),
          secondary: Text(
            '${item.count}',
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
        );
      },
    );
  }
}
