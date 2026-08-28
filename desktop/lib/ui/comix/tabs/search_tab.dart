import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:northstar/application/comix/providers/comix_providers.dart';
import 'package:northstar/app/theme.dart';
import 'package:northstar/domain/comix/models/comix_models.dart';
import 'package:northstar/ui/comix/widgets/comix_dialogs.dart';
import 'package:northstar/ui/comix/widgets/comix_widgets.dart';

/// 搜索添加 Tab：关键词 + 站点过滤 + 候选列表（点击添加）。
class SearchTab extends ConsumerStatefulWidget {
  const SearchTab({super.key});

  @override
  ConsumerState<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends ConsumerState<SearchTab> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _doSearch() async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) {
      _snack('请输入漫画名称');
      return;
    }
    FocusScope.of(context).unfocus();
    await ref.read(comixSearchProvider.notifier).startSearch(keyword);
  }

  Future<void> _addCandidate(ComixCandidate candidate) async {
    final options = await showAddComicDialog(context, candidate);
    if (options == null) return;
    try {
      // add-url：直接按详情 URL 添加，避免 add 重新搜索导致候选漂移
      await ref
          .read(comixBoardProvider.notifier)
          .startTask('add-url', options.toBody(candidate));
      ref.invalidate(comixComicsProvider);
      _snack('已提交添加任务：${candidate.title}');
    } catch (e) {
      _snack('提交添加失败: $e');
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final search = ref.watch(comixSearchProvider);
    final sites = ref.watch(comixSitesProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimens.paddingL),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.paddingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('搜索添加', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppDimens.spacingM),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        labelText: '漫画名称',
                        hintText: '如：海贼王',
                      ),
                      onSubmitted: (_) => _doSearch(),
                    ),
                  ),
                  const SizedBox(width: AppDimens.spacingM),
                  SizedBox(
                    width: 160,
                    child: sites.when(
                      data: (list) => DropdownButtonFormField<String>(
                        initialValue: search.siteFilter ?? '',
                        decoration: const InputDecoration(labelText: '站点'),
                        items: [
                          const DropdownMenuItem<String>(
                            value: '',
                            child: Text('全部站点'),
                          ),
                          for (final site in list)
                            DropdownMenuItem<String>(
                              value: site.code,
                              child: Text('${site.name} (${site.code})'),
                            ),
                        ],
                        onChanged: (v) => ref
                            .read(comixSearchProvider.notifier)
                            .setSiteFilter(v == null || v.isEmpty ? null : v),
                      ),
                      loading: () => const SizedBox(
                        height: 56,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, _) => Text('站点加载失败: $e'),
                    ),
                  ),
                  const SizedBox(width: AppDimens.spacingM),
                  ElevatedButton.icon(
                    onPressed: search.searching ? null : _doSearch,
                    icon: search.searching
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search_rounded),
                    label: Text(search.searching ? '搜索中...' : '搜索'),
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.spacingM),
              if (search.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '搜索失败: ${search.error}',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              if (search.candidates.isNotEmpty) ...[
                const Divider(height: 1),
                const SizedBox(height: AppDimens.spacingS),
                Text(
                  '「${search.keyword}」候选 ${search.candidates.length} 个（点击添加）',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppDimens.spacingS),
                for (var i = 0; i < search.candidates.length; i++)
                  _CandidateTile(
                    candidate: search.candidates[i],
                    index: i,
                    onAdd: () => _addCandidate(search.candidates[i]),
                  ),
              ] else if (!search.searching && search.error == null)
                Text(
                  '输入名称搜索，候选可跨站对比后选择添加（添加走 add-url，直接按详情页确定添加）',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CandidateTile extends StatelessWidget {
  final ComixCandidate candidate;
  final int index;
  final VoidCallback onAdd;

  const _CandidateTile({
    required this.candidate,
    required this.index,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading: ComixStatusChip(
          ok: candidate.match == 'exact',
          label: candidate.match == 'exact' ? '精确' : '模糊',
        ),
        title: Text(
          candidate.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '[${candidate.siteName}] ${candidate.detailUrl}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: OutlinedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add_rounded, size: 16),
          label: Text('添加 #$index'),
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
          ),
        ),
      ),
    );
  }
}
