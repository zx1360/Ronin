import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/core/modals/text_input_dialog.dart';
import 'package:torrid/core/services/storage/app_database.dart';

import 'trace_data.dart';
import 'trace_store.dart';
import 'trace_timing.dart';
import 'trace_ui.dart';

Future<TraceSession?> openTraceEditor(
  BuildContext context,
  String sceneId, {
  TraceSession? session,
}) => Navigator.of(
  context,
).push(traceRoute<TraceSession>(_Editor(sceneId: sceneId, session: session)));

class _Editor extends ConsumerStatefulWidget {
  const _Editor({required this.sceneId, this.session});

  final String sceneId;
  final TraceSession? session;

  @override
  ConsumerState<_Editor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<_Editor> {
  late final _note = TextEditingController(text: widget.session?.note);
  late final _tags = decodeTraceTags(widget.session?.tagIdsJson ?? '[]');
  late String? _item = widget.session?.itemId;
  int? _duration;
  bool _busy = false;
  bool _dirty = false;
  String? _error;

  bool get _starting => widget.session == null;
  bool get _finished => widget.session?.endedMs != null;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _changed(VoidCallback update) => setState(() {
    update();
    _dirty = true;
    _error = null;
  });

  Future<void> _pickItem(TraceData data, TraceStore store) async {
    final editableCatalog = data.sceneById[widget.sceneId]?.deletion == null;
    final choices = data
        .itemsIn(widget.sceneId)
        .where((item) => !item.archived || item.id == _item);
    final result = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.66,
        child: Column(
          children: [
            const ListTile(title: Text('选择事项')),
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    title: const Text('仅记录场景'),
                    trailing: _item == null ? const Icon(Icons.check) : null,
                    onTap: () => Navigator.pop(context, ''),
                  ),
                  for (final item in choices)
                    ListTile(
                      title: Text(item.name),
                      subtitle: item.archived ? const Text('已归档') : null,
                      trailing: _item == item.id
                          ? const Icon(Icons.check)
                          : null,
                      onTap: () => Navigator.pop(context, item.id),
                    ),
                ],
              ),
            ),
            if (editableCatalog)
              SafeArea(
                top: false,
                minimum: const EdgeInsets.all(12),
                child: TextButton.icon(
                  onPressed: () => Navigator.pop(context, '+'),
                  icon: const Icon(Icons.add),
                  label: const Text('新建事项'),
                ),
              ),
          ],
        ),
      ),
    );
    if (!mounted || result == null) return;
    if (result != '+') {
      _changed(() => _item = result.isEmpty ? null : result);
      return;
    }
    final name = await showTextInputDialog(
      context,
      title: '新建事项',
      label: '名称',
      allowEmpty: false,
      maxLength: 48,
    );
    if (!mounted || name == null) return;
    await traceAction(context, () async {
      final item = await store.saveItem(widget.sceneId, name);
      if (mounted) _changed(() => _item = item.id);
    });
  }

  Future<void> _addTag(TraceStore store) async {
    final name = await showTextInputDialog(
      context,
      title: '新建标签',
      label: '名称',
      allowEmpty: false,
      maxLength: 24,
    );
    if (!mounted || name == null) return;
    await traceAction(context, () async {
      final tag = await store.saveTag(name);
      if (mounted) _changed(() => _tags.add(tag.id));
    });
  }

  Future<void> _adjust() async {
    final session = widget.session!;
    final duration = await editTraceDuration(
      context,
      session,
      _duration ?? (session.endedMs! - session.startedMs),
    );
    if (mounted && duration != null) _changed(() => _duration = duration);
  }

  Future<void> _save(TraceStore store, {bool delete = false}) async {
    if (_busy) return;
    if (delete &&
        !await confirmTraceDiscard(
          context,
          '删除记录？',
          '本次时长和留言将从回顾中移除。',
          action: '删除',
        )) {
      return;
    }
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final details = (itemId: _item, tagIds: _tags.toSet(), note: _note.text);
      final saved = switch (widget.session) {
        null => await store.start(widget.sceneId, details: details),
        final session when delete => await store.discard(session),
        final session when _dirty => await store.saveDetails(
          session,
          details: details,
          durationMs: _duration,
        ),
        final session => session,
      };
      if (mounted) Navigator.pop(context, saved);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = traceError(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final watch = ref.watch(traceDataProvider);
    final data = watch.value;
    final store = ref.watch(traceStoreProvider);
    final scene = data?.sceneById[widget.sceneId];
    final titleScene = scene == null || _starting
        ? scene
        : data!.historySceneFor(scene.id);
    final unavailable = scene?.archived == true || scene?.deletion != null;
    final theme = Theme.of(context);
    return PopScope<TraceSession>(
      canPop: !_dirty && !_busy,
      onPopInvokedWithResult: (popped, _) async {
        if (popped || _busy || !_dirty) return;
        if (await confirmTraceDiscard(
              context,
              '放弃本次编辑？',
              '填写的修改还未保存。',
              action: '放弃修改',
            ) &&
            context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _starting
                ? '开始计时'
                : _finished
                ? '编辑记录'
                : '本次详情',
          ),
          leading: BackButton(onPressed: () => Navigator.maybePop(context)),
          actions: [
            if (_finished)
              IconButton(
                tooltip: '删除记录',
                onPressed: _busy ? null : () => _save(store, delete: true),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(20, 8, 20, 14),
          child: FilledButton.icon(
            onPressed: _busy || scene == null || (_starting && unavailable)
                ? null
                : () => _save(store),
            icon: Icon(
              _starting ? Icons.play_arrow_rounded : Icons.check_rounded,
            ),
            label: Text(
              _busy
                  ? '正在写入…'
                  : _starting
                  ? '开始计时'
                  : '保存记录',
            ),
          ),
        ),
        body: data == null
            ? Center(
                child: watch.hasError
                    ? TextButton(
                        onPressed: () => ref.invalidate(traceDataProvider),
                        child: const Text('读取失败，重试'),
                      )
                    : const CircularProgressIndicator(),
              )
            : scene == null
            ? const Center(child: Text('找不到这个场景'))
            : ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
                children: [
                  TracePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          spacing: 9,
                          children: [
                            TraceDot(traceSceneColor(titleScene!.color)),
                            Expanded(
                              child: Text(
                                titleScene.name,
                                style: theme.textTheme.headlineSmall,
                              ),
                            ),
                          ],
                        ),
                        if (widget.session case final session?) ...[
                          const SizedBox(height: 8),
                          Text(
                            '${traceStamp(session.startedMs)} 开始',
                            style: theme.textTheme.bodySmall,
                          ),
                          if (_finished) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    traceHms(
                                      _duration ??
                                          (session.endedMs! -
                                              session.startedMs),
                                    ),
                                    style: theme.textTheme.headlineSmall,
                                  ),
                                ),
                                TextButton(
                                  onPressed: _busy ? null : _adjust,
                                  child: const Text('修正时长'),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                  if (_starting && unavailable)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('该场景当前无法开始计时。'),
                    ),
                  const SizedBox(height: 16),
                  TracePanel(
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      title: const Text('事项'),
                      subtitle: Text(data.itemById[_item]?.name ?? '仅记录场景'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: _busy ? null : () => _pickItem(data, store),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TracePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('标签', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 2,
                          children: [
                            for (final tag in data.tags.where(
                              (t) => !t.archived || _tags.contains(t.id),
                            ))
                              FilterChip(
                                label: Text(tag.name),
                                selected: _tags.contains(tag.id),
                                onSelected: _busy
                                    ? null
                                    : (selected) => _changed(
                                        () => selected
                                            ? _tags.add(tag.id)
                                            : _tags.remove(tag.id),
                                      ),
                              ),
                            ActionChip(
                              avatar: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('新建标签'),
                              onPressed: _busy ? null : () => _addTag(store),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _note,
                    enabled: !_busy,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      labelText: '留言',
                      alignLabelWithHint: true,
                    ),
                    onChanged: (_) {
                      if (!_dirty) _changed(() {});
                    },
                  ),
                  if (_error case final error?)
                    Text(
                      error,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                ],
              ),
      ),
    );
  }
}
