import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:torrid/core/services/storage/app_database.dart';

import 'trace_data.dart';
import 'trace_session_editor.dart';
import 'trace_store.dart';
import 'trace_timing.dart';

class TraceHistory extends StatefulWidget {
  const TraceHistory({super.key, required this.data, required this.store});

  final TraceData data;
  final TraceStore store;

  @override
  State<TraceHistory> createState() => _TraceHistoryState();
}

class _TraceHistoryState extends State<TraceHistory>
    with AutomaticKeepAliveClientMixin {
  DateTimeRange? _range;
  String _scene = '';
  String _item = '';
  String _tag = '';

  @override
  bool get wantKeepAlive => true;

  void _selectScene(String id) => setState(() {
    _scene = id;
    _item = '';
  });

  Future<void> _pickDates() async {
    final today = DateUtils.dateOnly(DateTime.now());
    var first = today;
    var last = today;
    for (final session in widget.data.history) {
      final start = DateUtils.dateOnly(traceDate(session.startedMs));
      final end = DateUtils.dateOnly(traceDate(session.endedMs!));
      if (start.isBefore(first)) first = start;
      if (end.isAfter(last)) last = end;
    }
    if (_range case final range?) {
      if (range.start.isBefore(first)) first = range.start;
      if (range.end.isAfter(last)) last = range.end;
    }
    final range = await showDateRangePicker(
      context: context,
      firstDate: first,
      lastDate: last,
      initialDateRange: _range,
      helpText: '选择回顾日期',
      cancelText: '取消',
      saveText: '查看',
    );
    if (mounted && range != null) setState(() => _range = range);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final data = widget.data;
    final report = _Report.build(
      data,
      _range,
      _scene,
      _item,
      _tag,
      DateTime.now(),
    );
    final scheme = Theme.of(context).colorScheme;
    final monthDay = DateFormat('MM.dd');
    final dateLabel = _range == null
        ? '全部日期'
        : '${monthDay.format(_range!.start)}–${monthDay.format(_range!.end)}';
    final usedScenes = data.history.map((s) => s.sceneId).toSet();
    final usedItems = data.history.map((s) => s.itemId).toSet();
    final usedTags = data.history
        .expand((s) => data.tagIdsBySession[s.id]!)
        .toSet();

    return CustomScrollView(
      key: const PageStorageKey('trace-history'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          sliver: SliverList.list(
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 2,
                children: [
                  InputChip(
                    avatar: const Icon(Icons.date_range_outlined, size: 18),
                    label: Text(dateLabel),
                    onPressed: _pickDates,
                    onDeleted: _range == null
                        ? null
                        : () => setState(() => _range = null),
                    tooltip: _range == null
                        ? '按日期筛选'
                        : '${DateFormat('yyyy.MM.dd').format(_range!.start)} 至 ${DateFormat('yyyy.MM.dd').format(_range!.end)}',
                  ),
                  _filter('全部场景', _scene, {
                    for (final s in data.scenes.where(
                      (s) =>
                          !s.archived ||
                          usedScenes.contains(s.id) ||
                          s.id == _scene,
                    ))
                      s.id: s.name,
                  }, _selectScene),
                  if (_scene.isNotEmpty)
                    _filter('全部事项', _item, {
                      '-': '未指定事项',
                      for (final i
                          in data
                              .itemsIn(_scene)
                              .where(
                                (i) =>
                                    !i.archived ||
                                    usedItems.contains(i.id) ||
                                    i.id == _item,
                              ))
                        i.id: i.name,
                    }, (id) => setState(() => _item = id)),
                  _filter('全部标签', _tag, {
                    for (final t in data.tags.where(
                      (t) =>
                          !t.archived ||
                          usedTags.contains(t.id) ||
                          t.id == _tag,
                    ))
                      t.id: t.name,
                  }, (id) => setState(() => _tag = id)),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('累计投入', style: Theme.of(context).textTheme.labelLarge),
                    Text(
                      traceDuration(report.total),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${report.entries.length} 次记录 · ${_range == null ? '近 8 个月趋势' : '所选日期趋势'}',
                    ),
                    const SizedBox(height: 12),
                    _Trend(buckets: report.buckets),
                  ],
                ),
              ),
              if (report.distribution.isNotEmpty) ...[
                const SizedBox(height: 22),
                Text(
                  _scene.isEmpty ? '场景分布' : '事项分布',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                for (final row in report.distribution)
                  _DistributionRow(
                    name: _scene.isEmpty
                        ? data.sceneById[row.key]!.name
                        : data.itemById[row.key]?.name ?? '未指定事项',
                    color: Color(
                      data.sceneById[_scene.isEmpty ? row.key : _scene]!.color,
                    ),
                    ms: row.value,
                    total: report.total,
                    onTap: _scene.isEmpty
                        ? () => _selectScene(row.key)
                        : () => setState(() => _item = row.key),
                  ),
              ],
              const SizedBox(height: 20),
              Text('计时记录', style: Theme.of(context).textTheme.titleMedium),
              if (report.entries.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 26),
                  child: Text('这个范围还没有记录。'),
                ),
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
          sliver: SliverList.builder(
            itemCount: report.entries.length,
            itemBuilder: (context, index) {
              final (session, ms) = report.entries[index];
              final scene = data.sceneById[session.sceneId]!;
              final item = data.itemById[session.itemId];
              final tags = data.tagIdsBySession[session.id]!.map(
                (id) => '#${data.tagById[id]!.name}',
              );
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                elevation: 0,
                child: ListTile(
                  leading: Icon(
                    Icons.circle,
                    size: 12,
                    color: Color(scene.color),
                  ),
                  title: Text(
                    item == null ? scene.name : '${scene.name} · ${item.name}',
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(traceStamp(session.startedMs)),
                      if (tags.isNotEmpty)
                        Text(
                          tags.join('  '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (session.note.isNotEmpty)
                        Text(
                          session.note,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                  trailing: Text(traceDuration(ms)),
                  onTap: () =>
                      editTraceSession(context, widget.store, data, session),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _filter(
    String label,
    String selected,
    Map<String, String> options,
    ValueChanged<String> choose,
  ) => MenuAnchor(
    menuChildren: [
      MenuItemButton(onPressed: () => choose(''), child: Text(label)),
      for (final entry in options.entries)
        MenuItemButton(
          onPressed: () => choose(entry.key),
          child: Text(entry.value),
        ),
    ],
    builder: (context, controller, _) => InputChip(
      label: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 142),
        child: Text(
          options[selected] ?? label,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      avatar: const Icon(Icons.expand_more, size: 18),
      selected: selected.isNotEmpty,
      onPressed: () =>
          controller.isOpen ? controller.close() : controller.open(),
      onDeleted: selected.isEmpty ? null : () => choose(''),
    ),
  );
}

class _Report {
  const _Report(this.total, this.distribution, this.entries, this.buckets);

  final int total;
  final List<MapEntry<String, int>> distribution;
  final List<(TraceSession, int)> entries;
  final List<_Bucket> buckets;

  factory _Report.build(
    TraceData data,
    DateTimeRange? range,
    String scene,
    String item,
    String tag,
    DateTime now,
  ) {
    final from = range?.start.millisecondsSinceEpoch;
    final until = range == null
        ? null
        : _dayAfter(range.end).millisecondsSinceEpoch;
    final buckets = _makeBuckets(range, now);
    final distribution = <String, int>{};
    final entries = <(TraceSession, int)>[];
    var total = 0;
    for (final s in data.history) {
      if (scene.isNotEmpty && s.sceneId != scene ||
          item.isNotEmpty && (s.itemId ?? '-') != item ||
          tag.isNotEmpty && !data.tagIdsBySession[s.id]!.contains(tag)) {
        continue;
      }
      final start = s.startedMs;
      final end = s.endedMs!;
      if (from != null && (end < from || end == from && start < end) ||
          until != null && start >= until) {
        continue;
      }
      final clippedStart = math.max(start, from ?? start);
      final clippedEnd = math.min(end, until ?? end);
      final ms = clippedEnd - clippedStart;
      total += ms;
      entries.add((s, ms));
      final key = scene.isEmpty ? s.sceneId : (s.itemId ?? '-');
      distribution.update(key, (value) => value + ms, ifAbsent: () => ms);
      for (final bucket in buckets) {
        bucket.ms += math.max(
          0,
          math.min(clippedEnd, bucket.end) -
              math.max(clippedStart, bucket.start),
        );
      }
    }
    return _Report(
      total,
      distribution.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
      entries,
      buckets,
    );
  }

  static List<_Bucket> _makeBuckets(DateTimeRange? range, DateTime now) {
    if (range == null) {
      return [
        for (var month = now.month - 7; month <= now.month; month++)
          _Bucket(
            DateTime(now.year, month),
            DateTime(now.year, month + 1),
            DateFormat('M月'),
          ),
      ];
    }
    final end = _dayAfter(range.end);
    final days = DateTime.utc(end.year, end.month, end.day)
        .difference(
          DateTime.utc(range.start.year, range.start.month, range.start.day),
        )
        .inDays;
    final step = (days / 8).ceil();
    final buckets = <_Bucket>[];
    for (var date = range.start; date.isBefore(end);) {
      final next = DateTime(date.year, date.month, date.day + step);
      final boundary = next.isBefore(end) ? next : end;
      buckets.add(_Bucket(date, boundary, DateFormat('MM/dd')));
      date = boundary;
    }
    return buckets;
  }

  static DateTime _dayAfter(DateTime day) =>
      DateTime(day.year, day.month, day.day + 1);
}

class _Bucket {
  _Bucket(DateTime from, DateTime until, DateFormat format)
    : start = from.millisecondsSinceEpoch,
      end = until.millisecondsSinceEpoch,
      label = format.format(from);

  final int start;
  final int end;
  final String label;
  int ms = 0;
}

class _Trend extends StatelessWidget {
  const _Trend({required this.buckets});

  final List<_Bucket> buckets;

  @override
  Widget build(BuildContext context) {
    final maxMs = buckets.fold(
      1,
      (maxMs, bucket) => math.max(maxMs, bucket.ms),
    );
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final bucket in buckets)
          Expanded(
            child: Tooltip(
              triggerMode: TooltipTriggerMode.tap,
              message:
                  '${traceStamp(bucket.start).split(' ').first} 至 ${traceStamp(bucket.end - 1).split(' ').first} · ${traceDuration(bucket.ms)}',
              child: Column(
                children: [
                  Container(
                    width: 14,
                    height: 3 + 48 * bucket.ms / maxMs,
                    decoration: BoxDecoration(
                      color: bucket.ms == 0
                          ? theme.colorScheme.outlineVariant
                          : theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    bucket.label,
                    maxLines: 1,
                    style: theme.textTheme.labelSmall,
                    overflow: TextOverflow.fade,
                    softWrap: false,
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
    required this.name,
    required this.color,
    required this.ms,
    required this.total,
    required this.onTap,
  });

  final String name;
  final Color color;
  final int ms;
  final int total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text(name)),
              Text(traceDuration(ms)),
              const Icon(Icons.chevron_right, size: 18),
            ],
          ),
          const SizedBox(height: 7),
          LinearProgressIndicator(
            value: total == 0 ? 0 : ms / total,
            color: color,
            minHeight: 5,
            borderRadius: BorderRadius.circular(8),
          ),
        ],
      ),
    ),
  );
}
