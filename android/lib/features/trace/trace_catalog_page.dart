import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/core/modals/text_input_dialog.dart';
import 'package:torrid/core/services/storage/app_database.dart';
import 'package:torrid/core/widgets/async_value_widget/async_value_widget.dart';

import 'trace_data.dart';
import 'trace_color_picker.dart';
import 'trace_scene.dart';
import 'trace_store.dart';
import 'trace_timing.dart';
import 'trace_ui.dart';

class TraceCatalogPage extends ConsumerWidget {
  const TraceCatalogPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(traceStoreProvider);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('管理时迹'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '场景'),
              Tab(text: '标签'),
            ],
          ),
        ),
        body: AsyncValueWidget<TraceData>(
          asyncValue: ref.watch(traceDataProvider),
          dataBuilder: (data) => TabBarView(
            children: [
              _CatalogList(
                key: const PageStorageKey('trace-scenes'),
                addLabel: '新建场景',
                empty: '添加常用场景，在计时页快速开始。',
                add: () => _editScene(context, store),
                archived: [
                  for (final scene in data.catalogScenes.where(
                    (s) => s.archived,
                  ))
                    _sceneRow(context, data, scene),
                ],
                children: [
                  for (final scene in data.catalogScenes.where(
                    (s) => !s.archived,
                  ))
                    _sceneRow(context, data, scene),
                ],
              ),
              _CatalogList(
                key: const PageStorageKey('trace-tags'),
                addLabel: '新建标签',
                empty: '标签可以在不同场景的记录中使用。',
                add: () => _editTag(context, store),
                archived: [
                  for (final tag in data.tags.where((t) => t.archived))
                    _tagRow(context, store, tag),
                ],
                children: [
                  for (final tag in data.tags.where((t) => !t.archived))
                    _tagRow(context, store, tag),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sceneRow(BuildContext context, TraceData data, TraceScene scene) =>
      ListTile(
        leading: TraceDot(traceSceneColor(scene.color), size: 12),
        title: Text(scene.name),
        subtitle: Text(
          '${data.itemsIn(scene.id).where((i) => !i.archived).length} 个事项',
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => Navigator.of(
          context,
        ).push(traceRoute<void>(_SceneCatalog(sceneId: scene.id))),
      );

  Widget _tagRow(BuildContext context, TraceStore store, TraceTag tag) =>
      _CatalogRow(
        name: tag.name,
        archived: tag.archived,
        edit: () => _editTag(context, store, tag),
        setArchived: () =>
            store.saveTag(tag.name, tag: tag, archived: !tag.archived),
      );

  Future<void> _editTag(
    BuildContext context,
    TraceStore store, [
    TraceTag? tag,
  ]) async {
    final name = await showTextInputDialog(
      context,
      title: tag == null ? '新建标签' : '编辑标签',
      initial: tag?.name ?? '',
      label: '名称',
      allowEmpty: false,
      maxLength: 24,
    );
    if (context.mounted && name != null) {
      await traceAction(context, () => store.saveTag(name, tag: tag));
    }
  }
}

class _SceneCatalog extends ConsumerWidget {
  const _SceneCatalog({required this.sceneId});

  final String sceneId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final watch = ref.watch(traceDataProvider);
    final store = ref.watch(traceStoreProvider);
    final current = watch.value?.sceneById[sceneId];
    final scene = current?.deletion == null ? current : null;
    return Scaffold(
      appBar: AppBar(
        title: Text(scene?.name ?? '场景'),
        actions: [
          if (scene != null) ...[
            IconButton(
              tooltip: '编辑场景',
              onPressed: () => _editScene(context, store, scene),
              icon: const Icon(Icons.edit_outlined),
            ),
            PopupMenuButton<void>(
              tooltip: '场景操作',
              itemBuilder: (_) => [
                PopupMenuItem(
                  onTap: () => _toggleScene(context, store, scene),
                  child: Text(scene.archived ? '恢复场景' : '归档场景'),
                ),
                PopupMenuItem(
                  onTap: () => _deleteScene(
                    context,
                    store,
                    scene,
                    watch.value!.history
                        .where((row) => row.sceneId == scene.id)
                        .length,
                  ),
                  child: Text(
                    '删除场景',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: AsyncValueWidget<TraceData>(
        asyncValue: watch,
        dataBuilder: (data) {
          if (scene == null) return const Center(child: Text('找不到这个场景'));
          final items = data.itemsIn(scene.id);
          Widget row(TraceItem item) => _CatalogRow(
            name: item.name,
            archived: item.archived,
            edit: () => _editItem(context, store, scene.id, item),
            delete: () => _deleteItem(
              context,
              store,
              item,
              data.history.where((row) => row.itemId == item.id).length,
            ),
            setArchived: () => store.saveItem(
              scene.id,
              item.name,
              item: item,
              archived: !item.archived,
            ),
          );
          return _CatalogList(
            addLabel: '新建事项',
            empty: '可直接为场景计时，也可添加具体事项。',
            add: scene.archived
                ? null
                : () => _editItem(context, store, scene.id),
            header: TracePanel(
              child: Row(
                spacing: 9,
                children: [
                  TraceDot(traceSceneColor(scene.color)),
                  Expanded(child: Text(scene.archived ? '已归档' : '累计投入')),
                  Text(
                    traceDuration(data.totals.scenes[scene.id] ?? 0),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
            archived: [
              for (final item in items.where((i) => i.archived)) row(item),
            ],
            children: [
              for (final item in items.where((i) => !i.archived)) row(item),
            ],
          );
        },
      ),
    );
  }

  Future<void> _toggleScene(
    BuildContext context,
    TraceStore store,
    TraceScene scene,
  ) async {
    if (!scene.archived && !await _confirmArchive(context, scene.name)) return;
    if (context.mounted) {
      await traceAction(
        context,
        () => store.saveScene(
          scene: scene,
          name: scene.name,
          color: scene.color,
          archived: !scene.archived,
        ),
      );
    }
  }

  Future<void> _editItem(
    BuildContext context,
    TraceStore store,
    String sceneId, [
    TraceItem? item,
  ]) async {
    final name = await showTextInputDialog(
      context,
      title: item == null ? '新建事项' : '编辑事项',
      initial: item?.name ?? '',
      label: '名称',
      allowEmpty: false,
      maxLength: 48,
    );
    if (context.mounted && name != null) {
      await traceAction(
        context,
        () => store.saveItem(sceneId, name, item: item),
      );
    }
  }

  Future<void> _deleteScene(
    BuildContext context,
    TraceStore store,
    TraceScene scene,
    int count,
  ) async {
    final mode = await _confirmDeletion(
      context,
      name: scene.name,
      category: '场景',
      destination: '「其他」',
      count: count,
    );
    if (!context.mounted || mode == null) return;
    await traceAction(context, () async {
      await store.deleteScene(scene, mode);
      if (context.mounted) Navigator.pop(context);
    });
  }

  Future<void> _deleteItem(
    BuildContext context,
    TraceStore store,
    TraceItem item,
    int count,
  ) async {
    final mode = await _confirmDeletion(
      context,
      name: item.name,
      category: '事项',
      destination: '所属场景',
      count: count,
    );
    if (context.mounted && mode != null) {
      await traceAction(context, () => store.deleteItem(item, mode));
    }
  }
}

Future<TraceDeletion?> _confirmDeletion(
  BuildContext context, {
  required String name,
  required String category,
  required String destination,
  required int count,
}) async {
  final title = '删除「$name」？';
  if (count == 0) {
    final confirmed = await confirmTraceDiscard(
      context,
      title,
      '删除后无法恢复此$category。',
      action: '删除$category',
    );
    return confirmed ? TraceDeletion.keep : null;
  }
  return showDialog<TraceDeletion>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(
        '此$category有 $count 条历史记录。可归入$destination，也可和$category一起永久删除。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, TraceDeletion.erase),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          child: Text('删除$category和记录'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, TraceDeletion.keep),
          child: Text('记录归入$destination'),
        ),
      ],
    ),
  );
}

Future<bool> _confirmArchive(BuildContext context, String name) =>
    confirmTraceDiscard(
      context,
      '归档「$name」？',
      '历史记录会保留，可在管理页恢复。',
      action: '归档',
      destructive: false,
    );

class _CatalogList extends StatelessWidget {
  const _CatalogList({
    super.key,
    required this.addLabel,
    required this.empty,
    required this.children,
    required this.archived,
    this.add,
    this.header,
  });

  final String addLabel;
  final String empty;
  final VoidCallback? add;
  final Widget? header;
  final List<Widget> children;
  final List<Widget> archived;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
    children: [
      if (header case final widget?) ...[widget, const SizedBox(height: 12)],
      if (add != null) ...[
        OutlinedButton.icon(
          onPressed: add,
          icon: const Icon(Icons.add_rounded),
          label: Text(addLabel),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 48),
            side: const BorderSide(color: traceLine),
          ),
        ),
        const SizedBox(height: 10),
      ],
      TracePanel(
        padding: children.isEmpty
            ? const EdgeInsets.all(16)
            : const EdgeInsets.symmetric(vertical: 4),
        child: children.isEmpty ? Text(empty) : Column(children: children),
      ),
      if (archived.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: TracePanel(
            padding: EdgeInsets.zero,
            child: ExpansionTile(
              key: const PageStorageKey('trace-archived-expanded'),
              title: Text('已归档（${archived.length}）'),
              shape: const Border(),
              collapsedShape: const Border(),
              children: archived,
            ),
          ),
        ),
    ],
  );
}

class _CatalogRow extends StatelessWidget {
  const _CatalogRow({
    required this.name,
    required this.archived,
    required this.edit,
    required this.setArchived,
    this.delete,
  });

  final String name;
  final bool archived;
  final VoidCallback edit;
  final Future<void> Function() setArchived;
  final VoidCallback? delete;

  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(name),
    onTap: edit,
    trailing: PopupMenuButton<VoidCallback>(
      tooltip: '$name的操作',
      onSelected: (action) => action(),
      itemBuilder: (_) => [
        PopupMenuItem(value: edit, child: const Text('编辑')),
        PopupMenuItem(
          value: () async {
            if (!archived && !await _confirmArchive(context, name)) return;
            if (context.mounted) await traceAction(context, setArchived);
          },
          child: Text(archived ? '恢复' : '归档'),
        ),
        if (delete != null)
          PopupMenuItem(
            value: delete,
            child: Text(
              '删除事项',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    ),
  );
}

Future<void> _editScene(
  BuildContext context,
  TraceStore store, [
  TraceScene? scene,
]) => showDialog<void>(
  context: context,
  builder: (_) => _SceneDialog(store: store, scene: scene),
);

class _SceneDialog extends StatefulWidget {
  const _SceneDialog({required this.store, this.scene});

  final TraceStore store;
  final TraceScene? scene;

  @override
  State<_SceneDialog> createState() => _SceneDialogState();
}

class _SceneDialogState extends State<_SceneDialog> {
  late final _name = TextEditingController(text: widget.scene?.name);
  late String _color = widget.scene?.color ?? traceDefaultColor;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.store.saveScene(
        scene: widget.scene,
        name: _name.text,
        color: _color,
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = traceError(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(widget.scene == null ? '新建场景' : '编辑场景'),
    content: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: '名称'),
          maxLength: 32,
          onChanged: (_) => setState(() {}),
          autofocus: true,
          enabled: !_saving,
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: TraceDot(traceSceneColor(_color), size: 24),
          title: const Text('场景颜色'),
          subtitle: Text(_color),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: _saving
              ? null
              : () async {
                  FocusScope.of(context).unfocus();
                  final color = await pickTraceColor(context, _color);
                  if (mounted && color != null) setState(() => _color = color);
                },
        ),
        if (_error case final error?)
          Text(
            error,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: _saving || _name.text.trim().isEmpty ? null : _save,
        child: const Text('保存'),
      ),
    ],
  );
}
