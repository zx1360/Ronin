import 'dart:collection';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:torrid/core/services/network/api_client.dart';
import 'package:torrid/features/chat/pages/chat_settings_page.dart';
import 'package:torrid/features/chat/providers/chat_providers.dart';
import 'package:torrid/features/chat/services/chat_api_service.dart';
import 'package:torrid/features/essay/models/essay.dart';
import 'package:torrid/features/essay/models/label.dart';
import 'package:torrid/features/essay/models/label_tree.dart';
import 'package:torrid/features/essay/providers/essay_data_provider.dart';
import 'package:torrid/features/essay/providers/status_provider.dart';
import 'package:torrid/features/essay/services/essay_label_suggestions.dart';
import 'package:torrid/features/essay/widgets/label_selector.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';

class EssayLabelSuggestionsPage extends ConsumerStatefulWidget {
  const EssayLabelSuggestionsPage({super.key});

  @override
  ConsumerState<EssayLabelSuggestionsPage> createState() =>
      _EssayLabelSuggestionsPageState();
}

class _EssayLabelSuggestionsPageState
    extends ConsumerState<EssayLabelSuggestionsPage> {
  final _results = <({Essay source, EssaySuggestions suggestions})>[];
  final _pending = Queue<String>();
  CancelToken? _request;
  int _count = 3;
  int _total = 0;
  int _processed = 0;
  String? _scopeId;
  String? _batchScopeId;
  String? _model;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _request?.cancel();
    super.dispose();
  }

  bool _canAnalyze(Essay essay, Set<String> hidden) =>
      !essay.labels.any(hidden.contains) && essay.content.trim().isNotEmpty;

  void _startBatch() {
    final labels = ref.read(labelStreamProvider).requireValue;
    final hidden = hiddenLabelIds(labels);
    final scope = _scopeId;
    final branch = scope == null ? null : labelSubtree(labels, [scope]);
    final sample = ref
        .read(essayStreamProvider)
        .requireValue
        .where(
          (essay) =>
              _canAnalyze(essay, hidden) &&
              (branch == null || essay.labels.any(branch.contains)),
        )
        .toList();
    if (branch == null) sample.shuffle();
    setState(() {
      _batchScopeId = scope;
      _processed = 0;
      _results.clear();
      _pending
        ..clear()
        ..addAll(
          (branch == null ? sample.take(_count) : sample).map(
            (essay) => essay.id,
          ),
        );
      _total = _pending.length;
      _model = null;
      _error = _pending.isEmpty ? '暂无可分析的随笔' : null;
    });
    if (_pending.isNotEmpty) _analyze();
  }

  Future<void> _analyze() async {
    final token = CancelToken();
    setState(() {
      _request = token;
      _error = null;
    });
    try {
      final api = ref.read(apiClientManagerProvider);
      final selected = ref.read(chatOptionsControllerProvider).model;
      final info = await ref.read(chatApiProvider).info(cancelToken: token);
      if (!mounted || token.isCancelled) return;
      final installed = info.candidates
          .where((item) => item.installed)
          .toList();
      if (installed.isEmpty) {
        throw StateError('暂无可用模型，请在对话设置中启动 Ollama');
      }
      final model = selected.isEmpty
          ? installed.where((item) => !item.vision).firstOrNull?.model ??
                installed.where((item) => item.current).firstOrNull?.model ??
                installed.first.model
          : installed
                .where(
                  (item) => item.model.toLowerCase() == selected.toLowerCase(),
                )
                .firstOrNull
                ?.model;
      if (model == null) {
        throw StateError('模型 $selected 当前不可用，请在对话设置中重新选择');
      }
      setState(() => _model = model);
      final scope = _batchScopeId;
      final store = ref.read(essayStoreProvider);
      List<Label>? catalog;
      Set<String> hidden = {};
      Set<String>? branch;
      Map<String, String> candidates = {};
      String? branchName;
      while (_pending.isNotEmpty) {
        final essay = await store.essay(_pending.first);
        if (!mounted || token.isCancelled) return;
        final labels = ref.read(labelStreamProvider).requireValue;
        if (!identical(catalog, labels)) {
          catalog = labels;
          hidden = hiddenLabelIds(labels);
          branch = scope == null ? null : labelSubtree(labels, [scope]);
          candidates = labelPaths(labels);
          branchName = candidates[scope];
          if (scope != null && (branchName == null || hidden.contains(scope))) {
            throw StateError('所选标签分支已不可用，请重新选择');
          }
          final currentBranch = branch;
          candidates.removeWhere(
            (id, _) =>
                hidden.contains(id) ||
                (currentBranch != null && !currentBranch.contains(id)),
          );
        }
        if (essay == null ||
            !_canAnalyze(essay, hidden) ||
            (branch != null && !essay.labels.any(branch.contains))) {
          setState(() {
            _pending.removeFirst();
            _total--;
          });
          continue;
        }
        final suggestions = await suggestEssay(
          api: api,
          model: model,
          essay: essay,
          labelPaths: candidates,
          branch: branchName,
          cancelToken: token,
        );
        if (!mounted || token.isCancelled) return;
        setState(() {
          _pending.removeFirst();
          _processed++;
          if (scope == null ||
              suggestions.labels.isNotEmpty ||
              suggestions.removeLabels.isNotEmpty) {
            _results.add((source: essay, suggestions: suggestions));
          }
        });
      }
    } catch (error) {
      if (mounted && !token.isCancelled) {
        setState(() {
          _error = error is StateError
              ? error.message.toString()
              : ApiClient.mapError(error).toString();
        });
      }
    } finally {
      if (mounted) setState(() => _request = null);
    }
  }

  Future<void> _apply(
    Essay source,
    String? title,
    List<String> labels,
    List<String> removeLabels,
    String? branchId,
  ) async {
    setState(() => _saving = true);
    var message = '已应用到随笔';
    try {
      await ref
          .read(essayStoreProvider)
          .acceptSuggestions(
            source,
            title: title,
            labelIds: labels,
            removeLabelIds: removeLabels,
            branchId: branchId,
          );
    } catch (error) {
      message = error is StateError
          ? error.message.toString()
          : error.toString();
    } finally {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  void _changeScope(String? scope) {
    if (scope == _scopeId) return;
    setState(() {
      _scopeId = scope;
      _batchScopeId = null;
      _pending.clear();
      _results.clear();
      _total = 0;
      _processed = 0;
      _error = null;
      _model = null;
    });
  }

  Future<void> _pickBranch(List<Label> labels, Set<String> parentIds) async {
    final hidden = hiddenLabelIds(labels);
    final essays = ref.read(essayStreamProvider).requireValue;
    final parents = countEssayLabels(
      essays.where((essay) => _canAnalyze(essay, hidden)),
      labels,
      countEveryAncestor: true,
    ).where((label) => parentIds.contains(label.id)).toList();
    final id = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.75,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LabelSelector(
              labels: parents,
              countUnit: ' 篇',
              selectedLabels: [if (_scopeId case final scope?) scope],
              onToggleLabel: (id) => Navigator.pop(context, id),
            ),
          ),
        ),
      ),
    );
    if (id != null && mounted) _changeScope(id);
  }

  @override
  Widget build(BuildContext context) {
    final running = _request != null;
    final labelState = ref.watch(labelStreamProvider);
    final essayState = ref.watch(essayStreamProvider);
    final dataReady = labelState.hasValue && essayState.hasValue;
    final labels = labelState.value ?? [];
    final hidden = hiddenLabelIds(labels);
    final paths = ref.watch(idMapProvider);
    final theme = Theme.of(context);
    final parentIds = {
      for (final label in labels)
        if (label.parentId case final id? when !hidden.contains(label.id)) id,
    };
    final random = _scopeId == null;
    final scopePath = paths[_scopeId];
    final controls = Card.filled(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('随机抽取'),
                  selected: random,
                  onSelected: running || _saving
                      ? null
                      : (_) => _changeScope(null),
                ),
                ActionChip(
                  avatar: const Icon(Icons.account_tree_outlined, size: 18),
                  label: Text(
                    scopePath ?? '选择标签分支',
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed:
                      running || _saving || !dataReady || parentIds.isEmpty
                      ? null
                      : () => _pickBranch(labels, parentIds),
                ),
              ],
            ),
            Text(
              random
                  ? '选中想保留的标题和标签，逐篇应用。'
                  : '分析关联此标签或任意下级标签的全部可见随笔，逐篇审核新增和移除项。',
            ),
            if (random)
              Wrap(
                spacing: 8,
                children: [
                  for (final count in [1, 3, 5, 10])
                    ChoiceChip(
                      label: Text('$count 篇'),
                      selected: _count == count,
                      onSelected: running || _saving
                          ? null
                          : (_) => setState(() => _count = count),
                    ),
                ],
              ),
            if (_total > 0) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(value: _processed / _total),
              const SizedBox(height: 8),
              Text(
                running && _pending.isNotEmpty
                    ? '正在分析第 ${_processed + 1} 篇，共 $_total 篇'
                    : '已分析 $_processed / $_total 篇${random ? '' : ' · ${_results.length} 篇有建议'}',
              ),
              if (_model case final model?)
                Text(model, style: theme.textTheme.bodySmall),
            ],
            if ((_error ??
                    labelState.error?.toString() ??
                    essayState.error?.toString())
                case final error?)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  error,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.icon(
                  onPressed:
                      _saving || !dataReady || (!random && scopePath == null)
                      ? null
                      : running
                      ? () => _request?.cancel()
                      : _pending.isNotEmpty
                      ? _analyze
                      : _startBatch,
                  icon: Icon(running ? Icons.stop : Icons.auto_awesome),
                  label: Text(
                    running
                        ? '停止分析'
                        : _pending.isNotEmpty
                        ? '继续分析'
                        : _total == 0
                        ? '开始分析'
                        : random
                        ? '再抽一批'
                        : '重新分析',
                  ),
                ),
                if (!running && _pending.isNotEmpty && random)
                  TextButton(
                    onPressed: _saving || !dataReady ? null : _startBatch,
                    child: const Text('换一批'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 标签建议'),
        actions: [
          IconButton(
            tooltip: '对话设置',
            onPressed: running
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ChatSettingsPage(),
                    ),
                  ),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _results.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) return controls;
          final result = _results[index - 1];
          final batchScope = _batchScopeId;
          return Consumer(
            key: ObjectKey(result.source),
            builder: (context, ref, _) {
              final essay = ref
                  .watch(essayByIdProvider(result.source.id))
                  .value;
              if (essay == null || essay.labels.any(hidden.contains)) {
                return const SizedBox.shrink();
              }
              return _SuggestionCard(
                source: result.source,
                essay: essay,
                suggestions: result.suggestions,
                paths: paths,
                hidden: hidden,
                onApply: _saving
                    ? null
                    : (title, ids, removed) => _apply(
                        result.source,
                        title,
                        ids,
                        removed,
                        batchScope,
                      ),
              );
            },
          );
        },
      ),
    );
  }
}

class _SuggestionCard extends StatefulWidget {
  const _SuggestionCard({
    required this.source,
    required this.essay,
    required this.suggestions,
    required this.paths,
    required this.hidden,
    required this.onApply,
  });

  final Essay source;
  final Essay essay;
  final EssaySuggestions suggestions;
  final Map<String, String> paths;
  final Set<String> hidden;
  final void Function(String?, List<String>, List<String>)? onApply;

  @override
  State<_SuggestionCard> createState() => _SuggestionCardState();
}

class _SuggestionCardState extends State<_SuggestionCard>
    with AutomaticKeepAliveClientMixin {
  late bool _useTitle = widget.source.title.isEmpty;
  late final _chosen = widget.suggestions.labels.toSet();
  final _removed = <String>{};

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final essay = widget.essay;
    final title = widget.suggestions.title;
    final essayTitle = essay.title.isEmpty ? '未命名随笔' : essay.title;
    final stale = essay.content != widget.source.content;
    final canUseTitle = !stale && essay.title == widget.source.title;
    final labelIds = widget.suggestions.labels
        .where(
          (id) =>
              widget.paths.containsKey(id) &&
              !widget.hidden.contains(id) &&
              !essay.labels.contains(id),
        )
        .toList();
    final picked = labelIds.where(_chosen.contains).toList();
    final removable = widget.suggestions.removeLabels
        .where(essay.labels.contains)
        .toList();
    final pickedRemovals = removable.where(_removed.contains).toList();
    final slots = (4 - essay.labels.length + pickedRemovals.length).clamp(0, 4);
    final hasTitle = title.isNotEmpty && title != essay.title;
    final pickedTitle = hasTitle && canUseTitle && _useTitle ? title : null;
    final canApply =
        !stale &&
        picked.length <= slots &&
        (pickedRemovals.isEmpty ||
            essay.labels.length + picked.length > pickedRemovals.length) &&
        (pickedTitle != null || picked.isNotEmpty || pickedRemovals.isNotEmpty);

    return Card.outlined(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('yyyy年M月d日').format(essay.date),
              style: theme.textTheme.labelMedium,
            ),
            const SizedBox(height: 4),
            Text(essayTitle, style: theme.textTheme.titleMedium),
            Text(essay.content, maxLines: 3, overflow: TextOverflow.ellipsis),
            TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                showDragHandle: true,
                isScrollControlled: true,
                builder: (context) => FractionallySizedBox(
                  heightFactor: 0.75,
                  child: SafeArea(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      children: [
                        Text(essayTitle, style: theme.textTheme.titleLarge),
                        const SizedBox(height: 12),
                        SelectableText(essay.content),
                      ],
                    ),
                  ),
                ),
              ),
              child: const Text('阅读正文'),
            ),
            Text(
              essay.labels.isEmpty
                  ? '暂无标签'
                  : '已有标签  ${essay.labels.map((id) => widget.paths[id] ?? id).join(' · ')}',
              style: theme.textTheme.bodySmall,
            ),
            const Divider(height: 24),
            if (stale)
              const Text('正文已修改，请重新分析')
            else if (!hasTitle && labelIds.isEmpty && removable.isEmpty)
              Text(
                title == essay.title && title.isNotEmpty ||
                        widget.suggestions.labels.any(essay.labels.contains) ||
                        widget.suggestions.removeLabels.any(
                          (id) => !essay.labels.contains(id),
                        )
                    ? '建议已应用'
                    : '没有新的建议',
              )
            else ...[
              if (widget.suggestions.reason.isNotEmpty)
                Text(widget.suggestions.reason),
              if (hasTitle) ...[
                Text(
                  canUseTitle ? '建议标题' : '建议标题 · 原标题已修改',
                  style: theme.textTheme.labelLarge,
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: pickedTitle != null,
                  title: Text(title),
                  onChanged: canUseTitle && widget.onApply != null
                      ? (value) => setState(() => _useTitle = value ?? false)
                      : null,
                ),
              ],
              if (labelIds.isNotEmpty) ...[
                Text('建议标签 · 还可添加 $slots 个', style: theme.textTheme.labelLarge),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final id in labelIds)
                      FilterChip(
                        label: Text(
                          widget.paths[id]!,
                          overflow: TextOverflow.ellipsis,
                        ),
                        selected: _chosen.contains(id),
                        onSelected:
                            widget.onApply == null ||
                                (!_chosen.contains(id) &&
                                    picked.length >= slots)
                            ? null
                            : (value) => setState(() {
                                if (value) {
                                  _chosen.add(id);
                                } else {
                                  _chosen.remove(id);
                                }
                              }),
                      ),
                  ],
                ),
              ],
              if (removable.isNotEmpty) ...[
                Text('建议移除', style: theme.textTheme.labelLarge),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final id in removable)
                      FilterChip(
                        label: Text(
                          widget.paths[id] ?? id,
                          overflow: TextOverflow.ellipsis,
                        ),
                        selected: _removed.contains(id),
                        onSelected: widget.onApply == null
                            ? null
                            : (selected) {
                                setState(() {
                                  if (selected) {
                                    _removed.add(id);
                                  } else {
                                    _removed.remove(id);
                                  }
                                });
                              },
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: canApply && widget.onApply != null
                    ? () => widget.onApply!(pickedTitle, picked, pickedRemovals)
                    : null,
                child: const Text('应用所选'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
