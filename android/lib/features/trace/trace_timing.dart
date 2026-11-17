import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:torrid/core/services/storage/app_database.dart';

import 'trace_store.dart';
import 'trace_ui.dart';

DateTime traceDate(int ms) => DateTime.fromMillisecondsSinceEpoch(ms);
DateTime traceDay(DateTime time, [int offset = 0]) =>
    DateTime(time.year, time.month, time.day + offset);
String traceStamp(int ms) =>
    DateFormat('yyyy.MM.dd HH:mm').format(traceDate(ms));
String traceTime(int ms) => DateFormat('HH:mm').format(traceDate(ms));

int traceOverlap(TraceSession session, int from, int until) => math.max(
  0,
  math.min(session.endedMs!, until) - math.max(session.startedMs, from),
);

String traceDuration(int ms) {
  final seconds = ms ~/ 1000;
  final hours = seconds ~/ 3600;
  final minutes = seconds ~/ 60 % 60;
  if (hours > 0) return '$hours 小时${minutes == 0 ? '' : ' $minutes 分'}';
  if (minutes > 0) {
    final remainder = seconds % 60;
    return '$minutes 分${remainder == 0 ? '' : ' $remainder 秒'}';
  }
  return '$seconds 秒';
}

String traceHms(int ms) {
  final seconds = ms ~/ 1000;
  return [
    seconds ~/ 3600,
    seconds ~/ 60 % 60,
    seconds % 60,
  ].map((value) => value.toString().padLeft(2, '0')).join(':');
}

Widget traceCalendarStyle(BuildContext context, Widget? child) =>
    Localizations.override(
      context: context,
      locale: const Locale('zh', 'CN'),
      delegates: GlobalMaterialLocalizations.delegates,
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );

Future<int?> editTraceDuration(
  BuildContext context,
  TraceSession session,
  int initialMs, {
  int? latestEndMs,
}) => showDialog<int>(
  context: context,
  builder: (context) => Theme(
    data: traceTheme(Theme.of(context)),
    child: _DurationDialog(
      startedMs: session.startedMs,
      initialMs: initialMs,
      latestEndMs: latestEndMs,
    ),
  ),
);

class _DurationDialog extends StatefulWidget {
  const _DurationDialog({
    required this.startedMs,
    required this.initialMs,
    this.latestEndMs,
  });

  final int startedMs;
  final int initialMs;
  final int? latestEndMs;

  @override
  State<_DurationDialog> createState() => _DurationDialogState();
}

class _DurationDialogState extends State<_DurationDialog> {
  late final _fields = [
    for (final part in traceHms(widget.initialMs).split(':'))
      TextEditingController(text: part),
  ];
  late int _duration = widget.initialMs;
  String? _error;

  @override
  void dispose() {
    for (final field in _fields) {
      field.dispose();
    }
    super.dispose();
  }

  String? _validate(int ms) {
    if (ms < 0) return '结束时间不能早于开始时间';
    final limit = widget.latestEndMs;
    if (limit != null && widget.startedMs + ms > limit) {
      return '结束时间不能晚于本次计时的截止时刻';
    }
    return null;
  }

  void _readFields() {
    final [h, m, s] = _fields
        .map((field) => int.tryParse(field.text) ?? 0)
        .toList();
    final duration = Duration(hours: h, minutes: m, seconds: s).inMilliseconds;
    setState(() {
      _error = m > 59 || s > 59 ? '分钟和秒应为 0–59' : _validate(duration);
      if (_error == null) _duration = duration;
    });
  }

  Future<void> _pickEnd() async {
    FocusScope.of(context).unfocus();
    final start = traceDate(widget.startedMs);
    final estimate = traceDate(widget.startedMs + _duration);
    final lastDate = traceDate(
      widget.latestEndMs ??
          math.max(
            estimate.millisecondsSinceEpoch,
            DateTime.now().millisecondsSinceEpoch,
          ),
    );
    final date = await showDatePicker(
      context: context,
      firstDate: start,
      lastDate: lastDate,
      initialDate: estimate,
      helpText: '选择结束日期',
      cancelText: '返回',
      confirmText: '下一步',
      builder: traceCalendarStyle,
    );
    if (!mounted || date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(estimate),
      helpText: '选择结束时间',
      cancelText: '返回',
      confirmText: '确定',
      builder: traceCalendarStyle,
    );
    if (!mounted || time == null) return;
    final ms =
        DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        ).millisecondsSinceEpoch -
        widget.startedMs;
    setState(() {
      _error = _validate(ms);
      if (_error != null) return;
      _duration = ms;
      for (final (index, part) in traceHms(ms).split(':').indexed) {
        _fields[index].text = part;
      }
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('修正时长'),
    scrollable: true,
    content: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('开始于 ${traceStamp(widget.startedMs)}'),
        const SizedBox(height: 18),
        Row(
          spacing: 8,
          children: [
            for (final (index, field) in _fields.indexed)
              Expanded(
                child: TextField(
                  controller: field,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(index == 0 ? 7 : 2),
                  ],
                  onChanged: (_) => _readFields(),
                  decoration: InputDecoration(
                    labelText: const ['小时', '分', '秒'][index],
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (_error case final message?)
          Text(
            message,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          )
        else
          Text('结束于 ${traceStamp(widget.startedMs + _duration)}'),
        TextButton(onPressed: _pickEnd, child: const Text('选择结束日期和时间')),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: _error == null
            ? () => Navigator.pop(context, _duration)
            : null,
        child: const Text('应用'),
      ),
    ],
  );
}

Future<bool> recoverTrace(
  BuildContext context,
  TraceStore store, {
  bool importedOnly = false,
}) async {
  final sessions = await store.running(importedOnly: importedOnly);
  if (sessions.isEmpty) return false;
  final clock = await store.readClock();
  var changed = false;
  for (final (index, session) in sessions.indexed) {
    final name = await store.sceneName(session.sceneId);
    if (!context.mounted) return changed;
    final updated = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Theme(
        data: traceTheme(Theme.of(context)),
        child: _RecoveryDialog(
          store: store,
          session: session,
          name: name,
          suggestedMs: clock.durationMs(session),
          estimated: !clock.matches(session),
          position: sessions.length == 1
              ? null
              : '${index + 1}/${sessions.length}',
        ),
      ),
    );
    changed |= updated ?? false;
  }
  return changed;
}

class _RecoveryDialog extends StatefulWidget {
  const _RecoveryDialog({
    required this.store,
    required this.session,
    required this.name,
    required this.suggestedMs,
    required this.estimated,
    this.position,
  });

  final TraceStore store;
  final TraceSession session;
  final String name;
  final int suggestedMs;
  final bool estimated;
  final String? position;

  @override
  State<_RecoveryDialog> createState() => _RecoveryDialogState();
}

class _RecoveryDialogState extends State<_RecoveryDialog> {
  late TraceSession _session = widget.session;
  late int _ms = widget.suggestedMs;
  bool _busy = false;
  String? _error;

  Future<void> _commit(
    Future<TraceSession> Function() operation, {
    bool changed = true,
  }) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await operation();
      if (mounted) Navigator.pop(context, changed);
    } catch (error) {
      if (!mounted) return;
      if (error is StateError) {
        final current = await widget.store.sessionById(_session.id);
        if (!mounted) return;
        if (current == null || current.endedMs != null) {
          Navigator.pop(context, false);
          return;
        }
        _session = current;
      }
      setState(() {
        _error = traceError(error);
        _busy = false;
      });
    }
  }

  Future<void> _adjust() async {
    final duration = await editTraceDuration(
      context,
      _session,
      _ms,
      latestEndMs: widget.estimated
          ? null
          : _session.startedMs + widget.suggestedMs,
    );
    if (mounted && duration != null) setState(() => _ms = duration);
  }

  Future<void> _discard() async {
    if (await confirmTraceDiscard(context, '丢弃这次计时？', '本次时长和留言将从时迹移除。') &&
        mounted) {
      await _commit(() => widget.store.discard(_session));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(
          widget.position == null ? '恢复未结束的计时' : '恢复计时 · ${widget.position}',
        ),
        scrollable: true,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.name, style: theme.textTheme.titleLarge),
            Text(
              '${traceStamp(widget.session.startedMs)} 开始',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TracePanel(
              color: const Color(0xffedf1e7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.estimated && _ms == widget.suggestedMs
                        ? '系统时间估算'
                        : '将计入',
                  ),
                  Text(
                    traceHms(_ms),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            if (_error case final error?)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  error,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy
                  ? null
                  : () => _commit(() => widget.store.finish(_session, _ms)),
              child: const Text('结束并保存'),
            ),
            const SizedBox(height: 6),
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () => _commit(
                      () => widget.store.resume(
                        _session,
                        durationMs: _ms == widget.suggestedMs ? null : _ms,
                      ),
                      changed: false,
                    ),
              child: const Text('继续计时'),
            ),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _busy ? null : _adjust,
                  child: const Text('修正时长'),
                ),
                TextButton(
                  onPressed: _busy ? null : _discard,
                  child: const Text(
                    '丢弃',
                    style: TextStyle(color: Color(0xff9c4335)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
