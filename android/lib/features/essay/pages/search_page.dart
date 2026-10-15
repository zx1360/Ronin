import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:torrid/features/essay/models/essay.dart';
import 'package:torrid/features/essay/models/essay_search.dart';
import 'package:torrid/features/essay/pages/detail_page.dart';
import 'package:torrid/features/essay/providers/box_provider.dart';
import 'package:torrid/features/essay/providers/search_provider.dart';
import 'package:torrid/features/essay/providers/setting_provider.dart';

class EssaySearchPage extends ConsumerStatefulWidget {
  const EssaySearchPage({super.key});

  @override
  ConsumerState<EssaySearchPage> createState() => _EssaySearchPageState();
}

class _EssaySearchPageState extends ConsumerState<EssaySearchPage> {
  final _controller = TextEditingController();
  Timer? _debounce;
  var _query = EssaySearchQuery('');

  void _apply(String text) {
    _debounce?.cancel();
    setState(() => _query = EssaySearchQuery(text));
  }

  void _change(String text) {
    _debounce?.cancel();
    if (text.trim().isEmpty) {
      _apply(text);
    } else {
      _debounce = Timer(const Duration(milliseconds: 180), () => _apply(text));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(contentServerProvider);
    final settings = ref.watch(browseManagerProvider);
    final index = ref.watch(essaySearchIndexProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('全文搜索')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: _change,
              onSubmitted: _apply,
              decoration: InputDecoration(
                hintText: '搜索标题、正文、留言',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: '清空搜索',
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _controller.clear();
                    _apply('');
                  },
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              '跨年份 · 沿用标签筛选 · ${settings.showHidden ? '含隐藏随笔' : '不含隐藏随笔'}\n多个关键词用空格分隔，需全部匹配',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: _query.isEmpty
                ? const Center(child: Text('输入文字，找回以前记录的片段'))
                : index.when(
                    skipLoadingOnRefresh: false,
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) => Center(child: Text('搜索失败：$error')),
                    data: (index) {
                      final results = index.search(_query);
                      if (results.isEmpty) {
                        return const Center(child: Text('当前筛选范围内没有匹配的随笔'));
                      }
                      return Column(
                        children: [
                          Text(
                            '找到 ${results.length} 篇',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Expanded(
                            child: ListView.builder(
                              key: ValueKey(_query),
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                              itemCount: results.length,
                              itemBuilder: (context, index) => _SearchResult(
                                key: ValueKey(results[index].id),
                                essay: results[index],
                                query: _query,
                                onTap: () {
                                  final essay = ref
                                      .read(essayBoxProvider)
                                      .get(results[index].id);
                                  if (essay == null) return;
                                  FocusManager.instance.primaryFocus?.unfocus();
                                  ref
                                      .read(contentServerProvider.notifier)
                                      .switchEssay(essay);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const EssayDetailPage(),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }
}

class _SearchResult extends StatelessWidget {
  final Essay essay;
  final EssaySearchQuery query;
  final VoidCallback onTap;

  const _SearchResult({
    super.key,
    required this.essay,
    required this.query,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final excerpt = query.excerpt(essay);
    Widget highlight(String text, TextStyle? style, int lines) {
      final spans = <TextSpan>[];
      var offset = 0;
      for (final hit in query.pattern.allMatches(text)) {
        spans.add(TextSpan(text: text.substring(offset, hit.start)));
        spans.add(
          TextSpan(
            text: hit.group(0),
            style: TextStyle(
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              color: Theme.of(context).colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
        offset = hit.end;
      }
      spans.add(TextSpan(text: text.substring(offset)));
      return Text.rich(
        TextSpan(children: spans),
        style: style,
        maxLines: lines,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${DateFormat('yyyy年MM月dd日').format(essay.date)}${excerpt.fromMessage ? ' · 留言匹配' : ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (essay.title.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                highlight(
                  essay.title,
                  Theme.of(context).textTheme.titleMedium,
                  2,
                ),
              ],
              const SizedBox(height: 8),
              highlight(
                excerpt.text,
                Theme.of(context).textTheme.bodyMedium,
                4,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
