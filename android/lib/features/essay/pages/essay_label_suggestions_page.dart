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
import 'package:torrid/features/essay/services/essay_label_suggestions.dart';

class EssayLabelSuggestionsPage extends ConsumerStatefulWidget {
  const EssayLabelSuggestionsPage({super.key});

  @override
  ConsumerState<EssayLabelSuggestionsPage> createState() =>
      _EssayLabelSuggestionsPageState();
}

class _EssayLabelSuggestionsPageState
    extends ConsumerState<EssayLabelSuggestionsPage> {
  final _results = <({Essay essay, List<String> labels})>[];
  Map<String, String> _paths = {};
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
    final hidden = hiddenLabelIds(labels);
    final paths = {
      for (final label in labels)
        if (!hidden.contains(label.id)) label.id: labelPath(label, labels),
    };
    final essays =
        visibleEssays(ref.read(essayBoxProvider).values, labels)
            .where(
              (e) =>
                  e.labels.length < 4 &&
                  e.content.trim().isNotEmpty &&
                  paths.keys.any((id) => !e.labels.contains(id)),
            )
            .toList()
          ..shuffle();
    final sample = essays.take(_count).toList();
    final token = CancelToken();
    setState(() {
      _request = token;
      _results.clear();
      _paths = paths;
      _total = sample.length;
      _error = null;
      _model = null;
    });
    try {
      if (sample.isEmpty) throw StateError('暂无可添加标签的随笔');
      final api = ref.read(chatApiProvider);
      final selected = ref.read(chatOptionsControllerProvider).model;
      final info = await api.info();
      if (token.isCancelled) return;
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
      for (final essay in sample) {
        final suggestions = await suggestEssayLabels(
          api: api,
          options: options,
          essay: essay,
          labelPaths: paths,
          cancelToken: token,
        );
        if (!mounted || token.isCancelled) return;
        setState(() => _results.add((essay: essay, labels: suggestions)));
      }
    } catch (e) {
      if (mounted && !token.isCancelled) {
        setState(() => _error = ApiClient.mapError(e).toString());
      }
    } finally {
      if (mounted) setState(() => _request = null);
    }
  }

  Future<void> _accept(Essay essay, String id, List<String> suggestions) async {
    setState(() => _saving = true);
    try {
      await ref
          .read(essayServiceProvider.notifier)
          .acceptSuggestedLabel(essay, id);
      if (mounted) setState(() => suggestions.remove(id));
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
    return Scaffold(
      appBar: AppBar(title: const Text('AI 标签建议')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('随机抽取随笔，由本机模型推荐已有标签。点击「采纳」才会写入。'),
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
            Card(
              child: ExpansionTile(
                initiallyExpanded: true,
                title: Text(
                  result.essay.title.isEmpty ? '未命名随笔' : result.essay.title,
                ),
                subtitle: Text(
                  result.essay.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                children: [
                  TextButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(
                          result.essay.title.isEmpty
                              ? '随笔正文'
                              : result.essay.title,
                        ),
                        content: SingleChildScrollView(
                          child: Text(result.essay.content),
                        ),
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
                  if (result.labels.isEmpty) const Text('暂无待采纳标签'),
                  for (final id in result.labels)
                    ListTile(
                      title: Text(_paths[id] ?? id),
                      trailing: TextButton(
                        onPressed: _saving
                            ? null
                            : () => _accept(result.essay, id, result.labels),
                        child: const Text('采纳'),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
