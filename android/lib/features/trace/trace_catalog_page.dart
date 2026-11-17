import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/core/modals/text_input_dialog.dart';
import 'package:torrid/core/services/storage/app_database.dart';
import 'package:torrid/core/widgets/async_value_widget/async_value_widget.dart';

import 'trace_data.dart';
import 'trace_defaults.dart';
import 'trace_store.dart';
import 'trace_timing.dart';

class TraceCatalogPage extends ConsumerWidget {
  const TraceCatalogPage({super.key});

  Future<void> _editScene(
    BuildContext context,
    TraceStore store, [
    TraceScene? scene,
  ]) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _SceneDialog(store: store, scene: scene),
    );
  }

  Future<void> _editItem(
    BuildContext context,
    TraceStore store,
    TraceScene scene, [
    TraceItem? item,
  ]) async {
    final name = await showTextInputDialog(
      context,
      title: item == null ? '添加事项' : '编辑事项',
      initial: item?.name ?? '',
      label: '事项名称',
      allowEmpty: false,
      maxLength: 48,
    );
    if (name != null && context.mounted) {
      await traceAction(
        context,
        () => store.saveItem(scene.id, name, item: item),
      );
    }
  }

  Future<void> _editTag(
    BuildContext context,
    TraceStore store, [
    TraceTag? tag,
  ]) async {
    final name = await showTextInputDialog(
      context,
      title: tag == null ? '添加标签' : '编辑标签',
      initial: tag?.name ?? '',
      label: '标签名称',
      allowEmpty: false,
      maxLength: 24,
    );
    if (name != null && context.mounted) {
      await traceAction(context, () => store.saveTag(name, tag: tag));
    }
  }

  Future<void> _remove(
    BuildContext context,
    String name,
    Future<void> Function() remove,
  ) async {
    if (await confirmTraceDiscard(context, '移除「$name」？', '已记录的计时仍可在回顾中查看。') &&
        context.mounted) {
      await traceAction(context, remove);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(traceStoreProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('场景与标签')),
      body: AsyncValueWidget<TraceData>(
        asyncValue: ref.watch(traceDataProvider),
        dataBuilder: (data) => ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          children: [
            ListTile(
              title: const Text('场景'),
              trailing: TextButton.icon(
                onPressed: () => _editScene(context, store),
                icon: const Icon(Icons.add),
                label: const Text('添加场景'),
              ),
            ),
            for (final scene in data.scenes.where((s) => !s.archived))
              ExpansionTile(
                key: PageStorageKey(scene.id),
                leading: Icon(
                  Icons.circle,
                  size: 14,
                  color: Color(scene.color),
                ),
                title: Text(scene.name),
                subtitle: const Text('管理事项'),
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.only(left: 32, right: 16),
                    title: const Text('编辑场景'),
                    leading: const Icon(Icons.edit_outlined),
                    onTap: () => _editScene(context, store, scene),
                    trailing: IconButton(
                      tooltip: '移除场景',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _remove(
                        context,
                        scene.name,
                        () => store.archiveScene(scene),
                      ),
                    ),
                  ),
                  for (final item
                      in data.itemsIn(scene.id).where((i) => !i.archived))
                    ListTile(
                      contentPadding: const EdgeInsets.only(
                        left: 32,
                        right: 16,
                      ),
                      leading: const Icon(Icons.notes_outlined),
                      title: Text(item.name),
                      onTap: () => _editItem(context, store, scene, item),
                      trailing: IconButton(
                        tooltip: '移除事项',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _remove(
                          context,
                          item.name,
                          () => store.archiveItem(item),
                        ),
                      ),
                    ),
                  TextButton.icon(
                    onPressed: () => _editItem(context, store, scene),
                    icon: const Icon(Icons.add),
                    label: const Text('添加事项'),
                  ),
                ],
              ),
            const Divider(indent: 16, endIndent: 16),
            ListTile(
              title: const Text('跨场景标签'),
              trailing: TextButton.icon(
                onPressed: () => _editTag(context, store),
                icon: const Icon(Icons.add),
                label: const Text('添加标签'),
              ),
            ),
            for (final tag in data.tags.where((t) => !t.archived))
              ListTile(
                leading: const Icon(Icons.sell_outlined),
                title: Text(tag.name),
                onTap: () => _editTag(context, store, tag),
                trailing: IconButton(
                  tooltip: '移除标签',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () =>
                      _remove(context, tag.name, () => store.archiveTag(tag)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SceneDialog extends StatefulWidget {
  const _SceneDialog({required this.store, this.scene});

  final TraceStore store;
  final TraceScene? scene;

  @override
  State<_SceneDialog> createState() => _SceneDialogState();
}

class _SceneDialogState extends State<_SceneDialog> {
  late final _name = TextEditingController(text: widget.scene?.name);
  late int _color = widget.scene?.color ?? traceColors.first;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await traceAction(context, () async {
      await widget.store.saveScene(
        scene: widget.scene,
        name: _name.text.trim(),
        color: _color,
      );
      if (mounted) Navigator.pop(context);
    });
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(widget.scene == null ? '添加场景' : '编辑场景'),
    content: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: '场景名称'),
          maxLength: 32,
          onChanged: (_) => setState(() {}),
          autofocus: true,
        ),
        const Text('场景颜色'),
        Wrap(
          spacing: 8,
          children: [
            for (final (index, color) in traceColors.indexed)
              IconButton.filled(
                tooltip: ['陶土', '鸢尾', '松绿', '雾蓝', '莓红', '麦金'][index],
                style: IconButton.styleFrom(
                  backgroundColor: Color(color),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => setState(() => _color = color),
                icon: Icon(
                  color == _color ? Icons.check : Icons.circle,
                  size: color == _color ? 20 : 8,
                ),
              ),
          ],
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
