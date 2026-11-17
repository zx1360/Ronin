import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:torrid/core/services/storage/app_database.dart';

import 'trace_data.dart';
import 'trace_report.dart';
import 'trace_scene.dart';
import 'trace_session_editor.dart';
import 'trace_timing.dart';
import 'trace_ui.dart';

enum _Period { today, week, month, all, custom }

const _emptyFilters = (scene: null, item: null, tag: null);

class TraceHistory extends StatefulWidget {
  const TraceHistory({super.key, required this.data});

  final TraceData data;

  @override
  State<TraceHistory> createState() => _TraceHistoryState();
}

class _TraceHistoryState extends State<TraceHistory>
    with AutomaticKeepAliveClientMixin {
  _Period _period = _Period.all;
  DateTimeRange? _custom;
  TraceFilters _filters = _emptyFilters;
  bool _expanded = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void didUpdateWidget(covariant TraceHistory oldWidget) {
    super.didUpdateWidget(oldWidget);
    final data = widget.data;
    if (identical(oldWidget.data, data)) return;
    var sceneId = _filters.scene;
    if (data.sceneById[sceneId]?.deletion == TraceSceneDeletion.keep.name) {
      sceneId = traceOtherSceneId;
    }
    if (sceneId != null &&
        !data.historyScenes.any((scene) => scene.id == sceneId)) {
      sceneId = null;
    }
    final itemId = _filters.item;
    _filters = (
      scene: sceneId,
      item:
          itemId == null ||
              itemId == traceNoItem ||
              data.historyItemsIn(sceneId).any((item) => item.id == itemId)
          ? itemId
          : null,
      tag: _filters.tag,
    );
  }

  void _setFilters(TraceFilters filters) => setState(() {
    _filters = filters;
    _expanded = false;
  });

  Future<void> _pickDates(DateTime today) async {
    var first = traceDay(today, -365);
    var last = today;
    for (final session in widget.data.history) {
      final start = traceDay(traceDate(session.startedMs));
      final end = traceDay(traceDate(session.endedMs!));
      if (start.isBefore(first)) first = start;
      if (end.isAfter(last)) last = end;
    }
    final old = _custom;
    if (old != null) {
      if (old.start.isBefore(first)) first = old.start;
      if (old.end.isAfter(last)) last = old.end;
    }
    final range = await showDateRangePicker(
      context: context,
      firstDate: first,
      lastDate: last,
      initialDateRange:
          old ?? DateTimeRange(start: traceDay(today, -6), end: today),
      helpText: '选择回顾日期',
      cancelText: '取消',
      saveText: '查看',
      builder: traceCalendarStyle,
    );
    if (mounted && range != null) {
      setState(() {
        _period = _Period.custom;
        _custom = range;
        _expanded = false;
      });
    }
  }

  Future<void> _pickFilters() async {
    final filters = await showModalBottomSheet<TraceFilters>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _FilterSheet(data: widget.data, initial: _filters),
    );
    if (mounted && filters != null) _setFilters(filters);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final today = traceDay(DateTime.now());
    final data = widget.data;
    final theme = Theme.of(context);
    final range = switch (_period) {
      _Period.today => DateTimeRange(start: today, end: today),
      _Period.week => DateTimeRange(start: traceDay(today, -6), end: today),
      _Period.month => DateTimeRange(start: traceDay(today, -29), end: today),
      _Period.all => null,
      _Period.custom => _custom,
    };
    final report = TraceReport.build(data, range, _filters, today);
    final labelDate = DateFormat('yyyy.MM.dd');
    final scene = data.historySceneById(_filters.scene);
    final item = data.itemById[_filters.item];
    final tag = data.tagById[_filters.tag];
    final distribution = _expanded
        ? report.distribution
        : report.distribution.take(4);

    return CustomScrollView(
      key: const PageStorageKey('trace-history'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
          sliver: SliverList.list(
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final (period, name) in const [
                    (_Period.today, '今天'),
                    (_Period.week, '7 天'),
                    (_Period.month, '30 天'),
                    (_Period.all, '全部'),
                  ])
                    ChoiceChip(
                      label: Text(name),
                      selected: _period == period,
                      showCheckmark: false,
                      onSelected: (_) => setState(() {
                        _period = period;
                        _expanded = false;
                      }),
                      visualDensity: VisualDensity.compact,
                    ),
                  IconButton(
                    tooltip: '自选日期',
                    style: IconButton.styleFrom(
                      backgroundColor: _period == _Period.custom
                          ? theme.colorScheme.primaryContainer
                          : null,
                    ),
                    onPressed: () => _pickDates(today),
                    icon: const Icon(Icons.date_range_outlined, size: 22),
                  ),
                ],
              ),
              if (_period == _Period.custom && range != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${labelDate.format(range.start)} – ${labelDate.format(range.end)}',
                  ),
                ),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _pickFilters,
                    icon: const Icon(Icons.filter_list_rounded, size: 18),
                    label: const Text('筛选'),
                  ),
                  if (_filters != _emptyFilters)
                    TextButton(
                      onPressed: () => _setFilters(_emptyFilters),
                      child: const Text('清除筛选'),
                    ),
                ],
              ),
              if (_filters != _emptyFilters)
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (scene != null)
                      InputChip(
                        label: Text(scene.name),
                        onDeleted: () => _setFilters((
                          scene: null,
                          item: null,
                          tag: _filters.tag,
                        )),
                      ),
                    if (_filters.item != null)
                      InputChip(
                        label: Text(item?.name ?? '仅场景'),
                        onDeleted: () => _setFilters((
                          scene: _filters.scene,
                          item: null,
                          tag: _filters.tag,
                        )),
                      ),
                    if (tag != null)
                      InputChip(
                        label: Text('#${tag.name}'),
                        onDeleted: () => _setFilters((
                          scene: _filters.scene,
                          item: _filters.item,
                          tag: null,
                        )),
                      ),
                  ],
                ),
              const SizedBox(height: 8),
              TracePanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('累计投入', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 2),
                    Text(
                      traceDuration(report.total),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${report.rows.length} 次记录${range == null ? ' · 近 6 个月趋势' : ''}',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    _Trend(buckets: report.buckets),
                  ],
                ),
              ),
              if (_filters.item == null && report.distribution.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  scene == null ? '场景分布' : '事项分布',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 7),
                TracePanel(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  child: Column(
                    children: [
                      for (final row in distribution)
                        _DistributionRow(
                          label: scene == null
                              ? data.historySceneById(row.key)!.name
                              : data.itemById[row.key]?.name ?? '仅场景',
                          color: traceSceneColor(
                            scene?.color ??
                                data.historySceneById(row.key)!.color,
                          ),
                          duration: row.value,
                          total: report.total,
                          open: scene == null
                              ? () => _setFilters((
                                  scene: row.key,
                                  item: null,
                                  tag: _filters.tag,
                                ))
                              : () => _setFilters((
                                  scene: scene.id,
                                  item: row.key,
                                  tag: _filters.tag,
                                )),
                        ),
                      if (report.distribution.length > 4)
                        TextButton(
                          onPressed: () =>
                              setState(() => _expanded = !_expanded),
                          child: Text(
                            _expanded
                                ? '收起'
                                : '全部 ${report.distribution.length} 项',
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Text('计时记录', style: theme.textTheme.titleLarge),
              if (report.rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TracePanel(
                    child: Text(
                      data.history.isEmpty ? '结束一次计时后，记录会出现在这里。' : '这个范围还没有记录。',
                    ),
                  ),
                ),
            ],
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            18 + MediaQuery.paddingOf(context).bottom,
          ),
          sliver: SliverList.builder(
            itemCount: report.rows.length,
            itemBuilder: (context, index) {
              final row = report.rows[index];
              final firstOfDay =
                  index == 0 || row.day != report.rows[index - 1].day;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (firstOfDay)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(3, 9, 0, 6),
                      child: Text(
                        row.day == today
                            ? '今天'
                            : DateFormat(
                                row.day.year == today.year
                                    ? 'M月d日'
                                    : 'yyyy年M月d日',
                              ).format(row.day),
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  _HistoryEntry(data: data, row: row),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.data, required this.initial});

  final TraceData data;
  final TraceFilters initial;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late TraceFilters _current = widget.initial;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final scene = _current.scene;
    final items = data.historyItemsIn(scene);
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('筛选记录', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 14),
            _select(
              '场景',
              scene,
              {
                for (final s in data.historyScenes)
                  s.id: '${s.name}${s.archived ? '（已归档）' : ''}',
              },
              (id) => setState(
                () => _current = (scene: id, item: null, tag: _current.tag),
              ),
            ),
            const SizedBox(height: 10),
            _select(
              '事项',
              _current.item,
              {
                traceNoItem: '仅场景',
                for (final i in items)
                  i.id:
                      '${scene == null ? '${data.historySceneFor(i.sceneId).name} · ' : ''}${i.name}',
              },
              (id) => setState(
                () => _current = (scene: scene, item: id, tag: _current.tag),
              ),
              key: ValueKey(scene),
            ),
            const SizedBox(height: 10),
            _select(
              '标签',
              _current.tag,
              {for (final t in data.tags) t.id: t.name},
              (id) => setState(
                () => _current = (scene: scene, item: _current.item, tag: id),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              spacing: 10,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, _emptyFilters),
                  child: const Text('清除'),
                ),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, _current),
                    child: const Text('应用筛选'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _select(
    String label,
    String? value,
    Map<String, String> items,
    ValueChanged<String?> change, {
    Key? key,
  }) => DropdownButtonFormField<String>(
    key: key,
    initialValue: items.containsKey(value) ? value : '',
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: [
      const DropdownMenuItem(value: '', child: Text('全部')),
      for (final entry in items.entries)
        DropdownMenuItem(
          value: entry.key,
          child: Text(entry.value, overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: (id) => change(id == '' ? null : id),
  );
}

class _Trend extends StatelessWidget {
  const _Trend({required this.buckets});

  final List<TraceBucket> buckets;

  @override
  Widget build(BuildContext context) {
    final peak = buckets.fold(
      1,
      (value, bucket) => math.max(value, bucket.duration),
    );
    final style = Theme.of(context).textTheme.labelSmall;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final bucket in buckets)
          Expanded(
            child: Tooltip(
              triggerMode: TooltipTriggerMode.tap,
              message:
                  '${traceStamp(bucket.start)} 至 ${traceStamp(bucket.end)} · ${traceDuration(bucket.duration)}',
              child: Column(
                children: [
                  SizedBox(
                    height: 45,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        width: 19,
                        height: 3 + (42 * bucket.duration / peak),
                        decoration: BoxDecoration(
                          color: bucket.duration > 0
                              ? const Color(0xff668c74)
                              : traceLine,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    bucket.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: style,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _DistributionRow extends StatelessWidget {
  const _DistributionRow({
    required this.label,
    required this.color,
    required this.duration,
    required this.total,
    required this.open,
  });

  final String label;
  final Color color;
  final int duration;
  final int total;
  final VoidCallback open;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: open,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        child: Column(
          children: [
            Row(
              spacing: 8,
              children: [
                TraceDot(color),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(traceDuration(duration)),
                const Icon(Icons.chevron_right_rounded, size: 17),
              ],
            ),
            const SizedBox(height: 6),
            ExcludeSemantics(
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : duration / total,
                color: color,
                minHeight: 4,
                borderRadius: BorderRadius.circular(6),
                backgroundColor: traceLine,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _HistoryEntry extends StatelessWidget {
  const _HistoryEntry({required this.data, required this.row});

  final TraceData data;
  final ({TraceSession session, int duration, DateTime day}) row;

  @override
  Widget build(BuildContext context) {
    final session = row.session;
    final scene = data.historySceneFor(session.sceneId);
    final item = data.itemById[session.itemId]?.name;
    final labels = data
        .tagsFor(session)
        .map((id) => '#${data.tagById[id]!.name}')
        .join('  ');
    final start = traceTime(session.startedMs);
    final end = traceTime(session.endedMs!);
    final sameDay =
        traceDay(traceDate(session.startedMs)) ==
        traceDay(traceDate(session.endedMs!));
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Material(
        color: tracePanel,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: traceLine),
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () =>
              openTraceEditor(context, session.sceneId, session: session),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  spacing: 8,
                  children: [
                    TraceDot(traceSceneColor(scene.color)),
                    Expanded(
                      child: Text(
                        item == null ? scene.name : '${scene.name} · $item',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      traceDuration(row.duration),
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ],
                ),
                Text(
                  sameDay
                      ? '$start–$end'
                      : '${DateFormat('M.d HH:mm').format(traceDate(session.startedMs))} – ${DateFormat('M.d HH:mm').format(traceDate(session.endedMs!))}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (session.note.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      session.note,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (labels.isNotEmpty)
                  Text(
                    labels,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
