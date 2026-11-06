import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/core/services/network/api_client.dart';
import 'package:torrid/features/chat/models/chat_options.dart';
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
  final _results = <({Essay essay, EssaySuggestions suggestions})>[];
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

  Future<void> _sample() async {
    final labels = ref.read(labelBoxProvider).values.toList();
    final essays = visibleEssays(
      ref.read(essayBoxProvider).values,
      labels,
    ).where((e) => e.content.trim().isNotEmpty).toList()..shuffle();
    final sample = essays.take(_count).toList();
    final token = CancelToken();
    setState(() {
      _request = token;
      _results.clear();
      _total = sample.length;
      _error = null;
      _model = null;
    });
    try {
      if (sample.isEmpty) throw StateError('暂无可分析的随笔');
      final api = ref.read(chatApiProvider);
      final selected = ref.read(chatOptionsControllerProvider).model;
      final info = await api.info(cancelToken: token);
      if (!mounted || token.isCancelled) return;
      final installed = info.candidates
          .where((item) => item.installed)
          .toList();
      if (installed.isEmpty) {
        throw StateError('暂无可用模型，请在对话设置的模型区启动 Ollama');
      }
      final model = selected.isNotEmpty
          ? selected
          : installed.where((item) => !item.vision).firstOrNull?.model ??
                installed.where((item) => item.current).firstOrNull?.model ??
                installed.first.model;
      setState(() => _model = model);
      final options = ChatOptions(
        model: model,
        numCtx: 8192,
        temperature: 0.1,
        customKeepAlive: true,
        keepAliveSeconds: 60,
      );
      for (final item in sample) {
        final essay = ref.read(essayBoxProvider).get(item.id);
        final labels = ref.read(labelBoxProvider).values.toList();
        final hidden = hiddenLabelIds(labels);
        if (essay == null ||
            essay.content.trim().isEmpty ||
            essay.labels.any(hidden.contains)) {
          setState(() => _total--);
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
        setState(() => _results.add((essay: essay, suggestions: suggestions)));
      }
    } catch (e) {
      if (mounted && !token.isCancelled) {
        setState(() => _error = ApiClient.mapError(e).toString());
      }
    } finally {
      if (mounted) setState(() => _request = null);
    }
  }

  Future<void> _accept(Future<void> Function(EssayService) save) async {
    setState(() => _saving = true);
    try {
      await save(ref.read(essayServiceProvider.notifier));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
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

    Widget resultCard(Essay source, EssaySuggestions suggestions, Essay essay) {
      final stale = essay.content != source.content;
      final title = suggestions.title;
      final labels = suggestions.labels.where(
        (id) =>
            paths.containsKey(id) &&
            !hidden.contains(id) &&
            !essay.labels.contains(id),
      );
      return Card(
        key: ValueKey(essay.id),
        child: ExpansionTile(
          initiallyExpanded: true,
          title: Text(essay.title.isEmpty ? '未命名随笔' : essay.title),
          subtitle: Text(
            essay.content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          children: [
            ListTile(
              title: const Text('已有标签'),
              subtitle: Text(
                essay.labels.isEmpty
                    ? '暂无'
                    : essay.labels.map((id) => paths[id] ?? id).join(' · '),
              ),
            ),
            TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(essay.title.isEmpty ? '随笔正文' : essay.title),
                  content: SingleChildScrollView(child: Text(essay.content)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('关闭'),
                    ),
                  ],
                ),
              ),
              child: const Text('查看正文'),
            ),
            if (stale)
              const ListTile(title: Text('正文已修改，请重新分析'))
            else ...[
              if (title.isNotEmpty && title != essay.title)
                ListTile(
                  title: Text(title),
                  subtitle: const Text('建议标题'),
                  trailing: TextButton(
                    onPressed: _saving || essay.title != source.title
                        ? null
                        : () => _accept(
                            (service) =>
                                service.acceptSuggestedTitle(source, title),
                          ),
                    child: const Text('采纳标题'),
                  ),
                ),
              if (labels.isEmpty) const ListTile(title: Text('暂无待采纳标签')),
              for (final id in labels)
                ListTile(
                  title: Text(paths[id]!),
                  trailing: TextButton(
                    onPressed: _saving || essay.labels.length >= 4
                        ? null
                        : () => _accept(
                            (service) =>
                                service.acceptSuggestedLabel(source, id),
                          ),
                    child: const Text('采纳标签'),
                  ),
                ),
            ],
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('AI 标签建议')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('随机抽取随笔，由本机模型建议标题和标签。点击「采纳」后写入。'),
          Row(
            children: [
              DropdownButton<int>(
                value: _count,
                items: [
                  for (final count in [1, 3, 5, 10])
                    DropdownMenuItem(value: count, child: Text('$count 篇')),
                ],
                onChanged: running || _saving
                    ? null
                    : (value) => setState(() => _count = value!),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _saving
                    ? null
                    : running
                    ? () => _request?.cancel()
                    : _sample,
                child: Text(running ? '停止分析' : '随机抽样分析'),
              ),
            ],
          ),
          if (running) const LinearProgressIndicator(),
          if (_total > 0)
            Text(
              '已分析 ${_results.length}/$_total 篇${_model == null ? '' : ' · $_model'}',
            ),
          if (_error case final error?) Text(error),
          for (final result in _results)
            if (currentById[result.essay.id] case final essay?
                when !essay.labels.any(hidden.contains))
              resultCard(result.essay, result.suggestions, essay),
        ],
      ),
    );
  }
}
