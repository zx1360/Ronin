import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:torrid/core/services/network/api_client.dart';
import 'package:torrid/features/chat/models/chat_options.dart';
import 'package:torrid/features/chat/pages/chat_settings_page.dart';
import 'package:torrid/features/chat/providers/chat_providers.dart';
import 'package:torrid/features/chat/services/chat_api_service.dart';
import 'package:torrid/features/essay/models/essay.dart';
import 'package:torrid/features/essay/models/label_tree.dart';
import 'package:torrid/features/essay/providers/box_provider.dart';
import 'package:torrid/features/essay/providers/essay_notifier_provider.dart';
import 'package:torrid/features/essay/providers/status_provider.dart';
import 'package:torrid/features/essay/services/essay_label_suggestions.dart';

class EssayLabelSuggestionsPage extends ConsumerStatefulWidget {
  const EssayLabelSuggestionsPage({super.key});

  @override
  ConsumerState<EssayLabelSuggestionsPage> createState() =>
      _EssayLabelSuggestionsPageState();
}

class _EssayLabelSuggestionsPageState
    extends ConsumerState<EssayLabelSuggestionsPage> {
  final _results = <({Essay source, EssaySuggestions suggestions})>[];
  final _pending = <String>[];
  CancelToken? _request;
  int _count = 3;
  int _total = 0;
  String? _model;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _request?.cancel();
    super.dispose();
  }

  void _startBatch() {
    final sample = visibleEssays(
      ref.read(essayBoxProvider).values,
      ref.read(labelBoxProvider).values,
    ).where((essay) => essay.content.trim().isNotEmpty).toList()..shuffle();
    setState(() {
      _results.clear();
      _pending
        ..clear()
        ..addAll(sample.take(_count).map((essay) => essay.id));
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
      final api = ref.read(chatApiProvider);
      final selected = ref.read(chatOptionsControllerProvider).model;
      final info = await api.info(cancelToken: token);
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
      final options = ChatOptions(
        model: model,
        numCtx: 8192,
        temperature: 0.1,
        customKeepAlive: true,
        keepAliveSeconds: 60,
      );
      while (_pending.isNotEmpty) {
        final essay = ref.read(essayBoxProvider).get(_pending.first);
        final labels = ref.read(labelBoxProvider).values.toList();
        final hidden = hiddenLabelIds(labels);
        if (essay == null ||
            essay.content.trim().isEmpty ||
            essay.labels.any(hidden.contains)) {
          setState(() {
            _pending.removeAt(0);
            _total--;
          });
          continue;
        }
        final suggestions = await suggestEssay(
          api: api,
          options: options,
          essay: essay,
          labelPaths: {
            for (final label in labels)
              if (!hidden.contains(label.id))
                label.id: labelPath(label, labels),
          },
          cancelToken: token,
        );
        if (!mounted || token.isCancelled) return;
        setState(() {
          _pending.removeAt(0);
          _results.add((source: essay, suggestions: suggestions));
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

  Future<void> _apply(Essay source, String? title, List<String> labels) async {
    setState(() => _saving = true);
    var message = '已应用到随笔';
    try {
      await ref
          .read(essayServiceProvider.notifier)
          .acceptSuggestions(source, title: title, labelIds: labels);
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

  @override
  Widget build(BuildContext context) {
    final running = _request != null;
    final hidden = hiddenLabelIds(ref.watch(labelsProvider));
    final paths = ref.watch(idMapProvider);
    final essays =
        ref.watch(essayStreamProvider).valueOrNull ??
        ref.read(essayBoxProvider).values;
    final currentById = {for (final essay in essays) essay.id: essay};
    final theme = Theme.of(context);

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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Card.filled(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('随机抽取随笔', style: theme.textTheme.titleMedium),
                  const Text('选中想保留的标题和标签，逐篇应用。'),
                  const SizedBox(height: 8),
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
                    LinearProgressIndicator(value: _results.length / _total),
                    const SizedBox(height: 8),
                    Text(
                      running
                          ? '正在分析第 ${_results.length + 1} 篇，共 $_total 篇'
                          : '已分析 ${_results.length} / $_total 篇',
                    ),
                    if (_model case final model?)
                      Text(model, style: theme.textTheme.bodySmall),
                  ],
                  if (_error case final error?)
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
                        onPressed: _saving
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
                              : '再抽一批',
                        ),
                      ),
                      if (!running && _pending.isNotEmpty)
                        TextButton(
                          onPressed: _saving ? null : _startBatch,
                          child: const Text('换一批'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          for (final result in _results)
            if (currentById[result.source.id] case final essay?
                when !essay.labels.any(hidden.contains))
              _SuggestionCard(
                key: ObjectKey(result.source),
                source: result.source,
                essay: essay,
                suggestions: result.suggestions,
                paths: paths,
                hidden: hidden,
                onApply: _saving
                    ? null
                    : (title, ids) => _apply(result.source, title, ids),
              ),
        ],
      ),
    );
  }
}

class _SuggestionCard extends StatefulWidget {
  const _SuggestionCard({
    super.key,
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
  final void Function(String?, List<String>)? onApply;

  @override
  State<_SuggestionCard> createState() => _SuggestionCardState();
}

class _SuggestionCardState extends State<_SuggestionCard> {
  late bool _useTitle = widget.source.title.isEmpty;
  late final _chosen = widget.suggestions.labels.toSet();

  @override
  Widget build(BuildContext context) {
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
    final slots = (4 - essay.labels.length).clamp(0, 4);
    final hasTitle = title.isNotEmpty && title != essay.title;
    final pickedTitle = hasTitle && canUseTitle && _useTitle ? title : null;
    final canApply =
        !stale &&
        picked.length <= slots &&
        (pickedTitle != null || picked.isNotEmpty);

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
            else if (!hasTitle && labelIds.isEmpty)
              Text(
                title == essay.title && title.isNotEmpty ||
                        widget.suggestions.labels.any(essay.labels.contains)
                    ? '建议已应用'
                    : '没有新的建议',
              )
            else ...[
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
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: canApply && widget.onApply != null
                    ? () => widget.onApply!(pickedTitle, picked)
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
