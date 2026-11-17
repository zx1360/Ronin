import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:torrid/core/modals/snack_bar.dart';
import 'package:torrid/core/services/storage/app_database.dart';

import 'trace_clock.dart';
import 'trace_store.dart';

DateTime traceDate(int ms) => DateTime.fromMillisecondsSinceEpoch(ms);

String traceStamp(int ms) =>
    DateFormat('yyyy.MM.dd HH:mm').format(traceDate(ms));

String traceDuration(int ms) {
  final seconds = ms ~/ 1000;
  final hours = seconds ~/ 3600;
  final minutes = seconds ~/ 60 % 60;
  if (hours > 0) return '$hours 小时${minutes == 0 ? '' : ' $minutes 分'}';
  if (minutes > 0) return '$minutes 分';
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

Future<void> traceAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (error) {
    if (context.mounted) displaySnackBar(context, '操作失败 · $error');
  }
}

class TraceEndInput extends StatefulWidget {
  const TraceEndInput({
    super.key,
    required this.session,
    required this.initialMs,
    required this.onChanged,
  });

  final TraceSession session;
  final int initialMs;
  final ValueChanged<int?> onChanged;

  @override
  State<TraceEndInput> createState() => _TraceEndInputState();
}

class _TraceEndInputState extends State<TraceEndInput> {
  late final _controller = TextEditingController(
    text: traceHms(widget.initialMs),
  );
  int? _ms;
  bool _invalid = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setDuration(int? ms) {
    setState(() {
      _ms = ms;
      _invalid = ms == null;
    });
    widget.onChanged(ms);
  }

  void _parse(String text) {
    final parts = RegExp(
      r'^(\d{1,7}):([0-5]\d):([0-5]\d)$',
    ).firstMatch(text.trim());
    _setDuration(
      parts == null
          ? null
          : Duration(
              hours: int.parse(parts[1]!),
              minutes: int.parse(parts[2]!),
              seconds: int.parse(parts[3]!),
            ).inMilliseconds,
    );
  }

  Future<void> _pickEnd() async {
    FocusScope.of(context).unfocus();
    final start = traceDate(widget.session.startedMs);
    final estimate = traceDate(
      widget.session.startedMs + (_ms ?? widget.initialMs),
    );
    final lastDate = traceDate(
      math.max(
        DateTime.now().millisecondsSinceEpoch,
        estimate.millisecondsSinceEpoch,
      ),
    );
    final date = await showDatePicker(
      context: context,
      firstDate: start,
      lastDate: lastDate,
      initialDate: estimate,
      helpText: '选择结束日期',
      cancelText: '取消',
      confirmText: '下一步',
    );
    if (!mounted || date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(estimate),
      helpText: '选择结束时间',
      cancelText: '取消',
      confirmText: '确定',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (!mounted || time == null) return;
    final end = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    final ms = end.millisecondsSinceEpoch - widget.session.startedMs;
    if (ms < 0) {
      displaySnackBar(context, '结束时间不能早于开始时间');
      return;
    }
    _controller.text = traceHms(ms);
    _setDuration(ms);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextField(
        controller: _controller,
        keyboardType: TextInputType.datetime,
        onChanged: _parse,
        decoration: InputDecoration(
          labelText: '计入时长（时:分:秒）',
          errorText: _invalid ? '请输入如 01:30:00 的时长' : null,
        ),
      ),
      TextButton.icon(
        onPressed: _pickEnd,
        icon: const Icon(Icons.event_available_outlined),
        label: const Text('指定结束时间'),
      ),
      if (!_invalid)
        Text(
          '结束于 ${traceStamp(widget.session.startedMs + (_ms ?? widget.initialMs))}',
        ),
    ],
  );
}

Future<bool> confirmTraceDiscard(
  BuildContext context,
  String title,
  String message,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('返回'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认移除'),
          ),
        ],
      ),
    ) ??
    false;

enum _Recovery { finish, resume, discard }

Future<bool> recoverTrace(
  BuildContext context,
  TraceStore store, {
  bool importedOnly = false,
}) async {
  final sessions = await store.running(importedOnly: importedOnly);
  for (final session in sessions) {
    final name = await store.sceneName(session.sceneId);
    final clock = await TraceClock.read();
    if (!context.mounted) return false;
    final result = await showDialog<({_Recovery action, int? duration})>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _RecoveryDialog(session: session, name: name, clock: clock),
    );
    switch (result?.action) {
      case _Recovery.finish:
        await store.finish(session, result!.duration!);
      case _Recovery.resume:
        await store.resume(session, await TraceClock.read());
      case _Recovery.discard:
        await store.discard(session);
      case null:
        return false;
    }
  }
  return sessions.isNotEmpty;
}

class _RecoveryDialog extends StatefulWidget {
  const _RecoveryDialog({
    required this.session,
    required this.name,
    required this.clock,
  });

  final TraceSession session;
  final String name;
  final TraceClock clock;

  @override
  State<_RecoveryDialog> createState() => _RecoveryDialogState();
}

class _RecoveryDialogState extends State<_RecoveryDialog> {
  late int? _duration = widget.clock.durationMs(widget.session);

  void _choose(_Recovery action) =>
      Navigator.pop(context, (action: action, duration: _duration));

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: AlertDialog(
      scrollable: true,
      title: const Text('有一条未结束的计时'),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${widget.name} · ${traceStamp(widget.session.startedMs)} 开始'),
          if (!widget.clock.matches(widget.session))
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('当前时长由系统时间估算，可在保存前修正。'),
            ),
          const SizedBox(height: 16),
          TraceEndInput(
            session: widget.session,
            initialMs: widget.clock.durationMs(widget.session),
            onChanged: (ms) => setState(() => _duration = ms),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () async {
            if (await confirmTraceDiscard(context, '取消本次计时？', '这次活动不会计入历史。') &&
                context.mounted) {
              _choose(_Recovery.discard);
            }
          },
          child: const Text('取消计时'),
        ),
        TextButton(
          onPressed: () => _choose(_Recovery.resume),
          child: const Text('继续计时'),
        ),
        FilledButton(
          onPressed: _duration == null ? null : () => _choose(_Recovery.finish),
          child: const Text('结束并保存'),
        ),
      ],
    ),
  );
}
