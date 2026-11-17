import 'package:flutter/material.dart';
import 'package:torrid/core/services/storage/app_database.dart';

import 'trace_data.dart';
import 'trace_store.dart';
import 'trace_timing.dart';

Future<void> editTraceSession(
  BuildContext context,
  TraceStore store,
  TraceData data,
  TraceSession session,
) => showDialog<void>(
  context: context,
  builder: (_) => _SessionDialog(store: store, data: data, session: session),
);

class _SessionDialog extends StatefulWidget {
  const _SessionDialog({
    required this.store,
    required this.data,
    required this.session,
  });

  final TraceStore store;
  final TraceData data;
  final TraceSession session;

  @override
  State<_SessionDialog> createState() => _SessionDialogState();
}

class _SessionDialogState extends State<_SessionDialog> {
  late final _note = TextEditingController(text: widget.session.note);
  late final _tags = {...widget.data.tagIdsBySession[widget.session.id]!};
  late String _itemId = widget.session.itemId ?? '';
  int? _duration;
  bool _invalidDuration = false;
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit({bool remove = false}) async {
    if (remove &&
        !await confirmTraceDiscard(context, '移除这条记录？', '该时长与留言将从回顾中移除。')) {
      return;
    }
    if (!mounted) return;
    setState(() => _busy = true);
    await traceAction(context, () async {
      if (remove) {
        await widget.store.discard(widget.session);
      } else {
        await widget.store.saveDetails(
          widget.session,
          item: widget.data.itemById[_itemId],
          tagIds: _tags,
          note: _note.text.trim(),
          durationMs: _duration,
        );
      }
      if (mounted) Navigator.pop(context);
    });
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final items = widget.data
        .itemsIn(session.sceneId)
        .where((i) => !i.archived || i.id == session.itemId);
    final tags = widget.data.tags.where(
      (t) => !t.archived || _tags.contains(t.id),
    );
    final scene = widget.data.sceneById[session.sceneId]!;
    return AlertDialog(
      title: Text(scene.name),
      scrollable: true,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${traceStamp(session.startedMs)} 开始'),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _itemId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: '事项'),
            items: [
              const DropdownMenuItem(value: '', child: Text('无指定事项')),
              for (final item in items)
                DropdownMenuItem(
                  value: item.id,
                  child: Text(item.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (value) => _itemId = value!,
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final tag in tags)
                  FilterChip(
                    label: Text(tag.name),
                    selected: _tags.contains(tag.id),
                    onSelected: (selected) {
                      setState(
                        () =>
                            selected ? _tags.add(tag.id) : _tags.remove(tag.id),
                      );
                    },
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            minLines: 2,
            maxLines: 5,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: '留言',
              alignLabelWithHint: true,
            ),
          ),
          if (session.endedMs != null)
            TraceEndInput(
              session: session,
              initialMs: session.endedMs! - session.startedMs,
              onChanged: (ms) => setState(() {
                _duration = ms;
                _invalidDuration = ms == null;
              }),
            ),
        ],
      ),
      actions: [
        if (session.endedMs != null)
          IconButton(
            onPressed: _busy ? null : () => _submit(remove: true),
            tooltip: '移除记录',
            icon: const Icon(Icons.delete_outline),
          ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _busy || _invalidDuration ? null : _submit,
          child: const Text('保存'),
        ),
      ],
    );
  }
}
