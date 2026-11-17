import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:torrid/core/services/storage/app_database.dart';

import 'trace_catalog_page.dart';
import 'trace_clock.dart';
import 'trace_data.dart';
import 'trace_session_editor.dart';
import 'trace_store.dart';
import 'trace_timing.dart';
import 'trace_ui.dart';

enum _TimerAction { details, adjust, discard }

class TraceDesk extends StatefulWidget {
  const TraceDesk({super.key, required this.data, required this.store});

  final TraceData data;
  final TraceStore store;

  @override
  State<TraceDesk> createState() => _TraceDeskState();
}

class _TraceDeskState extends State<TraceDesk> {
  final _scroll = ScrollController();
  final _pending = <String>{};

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _showTimers() {
    if (_scroll.hasClients && _scroll.offset > 0) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _scroll.jumpTo(0);
      } else {
        unawaited(
          _scroll.animateTo(
            0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
          ),
        );
      }
    }
  }

  Future<void> _run(String key, Future<void> Function() action) async {
    if (_pending.contains(key)) return;
    setState(() => _pending.add(key));
    await traceAction(context, action);
    if (mounted) setState(() => _pending.remove(key));
  }

  Future<void> _start(TraceScene scene, {String? itemId}) =>
      _run(scene.id, () async {
        await widget.store.start(
          scene.id,
          details: (itemId: itemId, tagIds: const {}, note: ''),
        );
        if (mounted) _showTimers();
      });

  Future<void> _prepare(TraceScene scene) async {
    final started = await openTraceEditor(context, scene.id);
    if (mounted && started != null) _showTimers();
  }

  Future<void> _finish(
    TraceSession session, {
    int? duration,
  }) => _run(session.id, () async {
    final saved = duration == null
        ? await widget.store.stop(session)
        : await widget.store.finish(session, duration);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text('已保存 ${traceDuration(saved.endedMs! - saved.startedMs)}'),
        action: SnackBarAction(
          label: '编辑',
          onPressed: () async {
            await traceAction(context, () async {
              final latest = await widget.store.sessionById(saved.id);
              if (mounted && latest != null) {
                await openTraceEditor(context, latest.sceneId, session: latest);
              }
            });
          },
        ),
      ),
    );
  });

  Future<void> _options(TraceSession session, _TimerAction action) async {
    switch (action) {
      case _TimerAction.details:
        await openTraceEditor(context, session.sceneId, session: session);
      case _TimerAction.adjust:
        await traceAction(context, () async {
          final clock = await widget.store.readClock();
          if (!mounted) return;
          final initial = clock.durationMs(session);
          final duration = await editTraceDuration(
            context,
            session,
            initial,
            latestEndMs: clock.matches(session)
                ? session.startedMs + initial
                : null,
          );
          if (mounted && duration != null) {
            await _finish(session, duration: duration);
          }
        });
      case _TimerAction.discard:
        if (await confirmTraceDiscard(context, '丢弃这次计时？', '本次时长和留言将从时迹移除。') &&
            mounted) {
          await _run(session.id, () => widget.store.discard(session));
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final activeIds = data.active.map((s) => s.sceneId).toSet();
    final scenes = data.scenes.where((s) => !s.archived).toList();
    final recent = data.history.firstOrNull;
    final recentScene = data.sceneById[recent?.sceneId];
    final item = data.itemById[recent?.itemId];
    final recentItem = item?.archived == false ? item : null;
    final theme = Theme.of(context);

    return CustomScrollView(
      key: const PageStorageKey('trace-desk'),
      controller: _scroll,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          sliver: SliverList.list(
            children: [
              if (data.active.isEmpty)
                _DeskSummary(data: data)
              else
                _RunningTimers(
                  data: data,
                  store: widget.store,
                  pending: _pending,
                  stop: _finish,
                  options: _options,
                ),
              if (data.active.isEmpty &&
                  recentScene != null &&
                  !recentScene.archived) ...[
                const SizedBox(height: 10),
                TracePanel(
                  padding: const EdgeInsets.fromLTRB(14, 4, 8, 4),
                  child: Row(
                    spacing: 10,
                    children: [
                      TraceDot(recentScene.color),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('上次计时', style: theme.textTheme.bodySmall),
                            Text(
                              recentItem == null
                                  ? recentScene.name
                                  : '${recentScene.name} · ${recentItem.name}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.replay_rounded, size: 18),
                        onPressed: _pending.contains(recentScene.id)
                            ? null
                            : () => _start(recentScene, itemId: recentItem?.id),
                        label: const Text('再计一次'),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text('场景', style: theme.textTheme.titleLarge),
              ),
              if (scenes.isEmpty)
                TracePanel(
                  child: ListTile(
                    title: const Text('添加你的第一个场景'),
                    trailing: const Icon(Icons.add_rounded),
                    onTap: () => Navigator.of(
                      context,
                    ).push(traceRoute<void>(const TraceCatalogPage())),
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
          sliver: SliverLayoutBuilder(
            builder: (context, constraints) {
              final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
              return SliverGrid.builder(
                itemCount: scenes.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount:
                      constraints.crossAxisExtent >= 290 && scale < 1.4 ? 2 : 1,
                  mainAxisExtent: 96 + math.max(0, scale - 1) * 48,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemBuilder: (context, index) {
                  final scene = scenes[index];
                  final running = activeIds.contains(scene.id);
                  return _SceneTile(
                    scene: scene,
                    total: data.totals.scenes[scene.id] ?? 0,
                    running: running,
                    start: running || _pending.contains(scene.id)
                        ? null
                        : () => _start(scene),
                    open: running ? _showTimers : () => _prepare(scene),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SceneTile extends StatelessWidget {
  const _SceneTile({
    required this.scene,
    required this.total,
    required this.running,
    required this.open,
    this.start,
  });

  final TraceScene scene;
  final int total;
  final bool running;
  final VoidCallback open;
  final VoidCallback? start;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: tracePanel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: traceLine),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: open,
        child: Padding(
          padding: const EdgeInsets.only(left: 12, right: 4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TraceDot(scene.color, size: 8),
                    const SizedBox(height: 6),
                    Text(
                      scene.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      running ? '计时中' : traceDuration(total),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: running ? '查看${scene.name}计时' : '开始${scene.name}',
                onPressed: running ? open : start,
                icon: Icon(
                  running ? Icons.timelapse_rounded : Icons.play_arrow_rounded,
                  color: traceForest,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xffebf0e6),
                  disabledBackgroundColor: const Color(0xffefeee8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeskSummary extends StatelessWidget {
  const _DeskSummary({required this.data});

  final TraceData data;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = traceDay(now).millisecondsSinceEpoch;
    final week = traceDay(now, 1 - now.weekday).millisecondsSinceEpoch;
    final until = traceDay(now, 1).millisecondsSinceEpoch;
    var todayMs = 0;
    var weekMs = 0;
    for (final row in data.history) {
      todayMs += traceOverlap(row, today, until);
      weekMs += traceOverlap(row, week, until);
    }
    return TracePanel(
      color: const Color(0xffe8eee2),
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('今日投入', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 5),
                Text(
                  traceDuration(todayMs),
                  style: const TextStyle(
                    fontSize: 31,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '本周 ${traceDuration(weekMs)}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const ExcludeSemantics(
            child: SizedBox(
              width: 116,
              height: 94,
              child: CustomPaint(painter: _DeskArt()),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeskArt extends CustomPainter {
  const _DeskArt();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 116, size.height / 94);
    final paint = Paint()..isAntiAlias = true;
    final window = RRect.fromRectAndCorners(
      const Rect.fromLTWH(19, 4, 68, 70),
      topLeft: const Radius.circular(34),
      topRight: const Radius.circular(34),
    );
    canvas.save();
    canvas.clipRRect(window);
    canvas.drawPaint(paint..color = const Color(0xfff6f0dc));
    canvas.drawCircle(
      const Offset(63, 30),
      9,
      paint..color = const Color(0xffd8a565),
    );
    canvas.drawPath(
      Path()
        ..moveTo(10, 55)
        ..quadraticBezierTo(34, 23, 57, 54)
        ..quadraticBezierTo(71, 39, 90, 56)
        ..lineTo(92, 78)
        ..lineTo(10, 78)
        ..close(),
      paint..color = const Color(0xffa7bba0),
    );
    canvas.drawPath(
      Path()
        ..moveTo(10, 66)
        ..quadraticBezierTo(42, 50, 60, 63)
        ..quadraticBezierTo(80, 68, 91, 51)
        ..lineTo(91, 76)
        ..lineTo(10, 76)
        ..close(),
      paint..color = const Color(0xff789781),
    );
    canvas.restore();
    paint
      ..color = const Color(0xff547760)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawRRect(window, paint);
    canvas.drawLine(const Offset(53, 4), const Offset(53, 73), paint);
    canvas.drawLine(const Offset(20, 47), const Offset(86, 47), paint);
    paint
      ..color = const Color(0xff996548)
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(13, 82), const Offset(108, 82), paint);
    canvas.drawOval(const Rect.fromLTWH(96, 63, 12, 10), paint);
    paint
      ..color = const Color(0xffb97e58)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        const Rect.fromLTWH(77, 61, 23, 18),
        bottomLeft: const Radius.circular(6),
        bottomRight: const Radius.circular(6),
      ),
      paint,
    );
    canvas.drawOval(
      const Rect.fromLTWH(77, 58, 23, 7),
      paint..color = const Color(0xfff7edd6),
    );
    paint
      ..color = const Color(0xff6a8a73)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    canvas.drawPath(
      Path()
        ..moveTo(87, 55)
        ..cubicTo(81, 49, 95, 45, 89, 39),
      paint,
    );
  }

  @override
  bool shouldRepaint(_DeskArt oldDelegate) => false;
}

class _RunningTimers extends StatefulWidget {
  const _RunningTimers({
    required this.data,
    required this.store,
    required this.pending,
    required this.stop,
    required this.options,
  });

  final TraceData data;
  final TraceStore store;
  final Set<String> pending;
  final ValueChanged<TraceSession> stop;
  final void Function(TraceSession, _TimerAction) options;

  @override
  State<_RunningTimers> createState() => _RunningTimersState();
}

class _RunningTimersState extends State<_RunningTimers>
    with WidgetsBindingObserver {
  Timer? _timer;
  TraceClock? _sample;
  final _sinceSample = Stopwatch();
  TabController? _tabs;
  bool _routeActive = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _routeActive =
        (ModalRoute.isCurrentOf(context) ?? true) &&
        TickerMode.valuesOf(context).enabled;
    final tabs = DefaultTabController.maybeOf(context);
    if (tabs != _tabs) {
      _tabs?.removeListener(_updateTicker);
      _tabs = tabs;
      tabs?.addListener(_updateTicker);
    }
    _updateTicker();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _updateTicker();

  void _updateTicker() {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    final visible =
        _routeActive &&
        (_tabs?.index ?? 0) == 0 &&
        (lifecycle == null || lifecycle == AppLifecycleState.resumed);
    if (visible && _timer == null) {
      unawaited(_sampleClock(++_generation));
      _timer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => setState(() {}),
      );
    } else if (!visible && _timer != null) {
      _generation++;
      _timer?.cancel();
      _timer = null;
      _sinceSample.stop();
    }
  }

  Future<void> _sampleClock(int generation) async {
    final sample = await widget.store.readClock();
    if (!mounted || generation != _generation) return;
    setState(() {
      _sample = sample;
      _sinceSample
        ..reset()
        ..start();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tabs?.removeListener(_updateTicker);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sample = _sample;
    final delta = _sinceSample.elapsedMilliseconds;
    final clock = TraceClock(
      wallMs: sample == null
          ? DateTime.now().millisecondsSinceEpoch
          : sample.wallMs + delta,
      bootKey: sample?.bootKey,
      elapsedMs: sample?.elapsedMs == null ? null : sample!.elapsedMs! + delta,
    );
    return Column(
      spacing: 10,
      children: [
        for (final session in widget.data.active)
          _RunningCard(
            key: ValueKey(session.id),
            session: session,
            scene: widget.data.sceneById[session.sceneId]!,
            item: widget.data.itemById[session.itemId]?.name,
            duration: clock.durationMs(session),
            disabled: widget.pending.contains(session.id),
            stop: () => widget.stop(session),
            options: (action) => widget.options(session, action),
          ),
      ],
    );
  }
}

class _RunningCard extends StatelessWidget {
  const _RunningCard({
    super.key,
    required this.session,
    required this.scene,
    required this.item,
    required this.duration,
    required this.disabled,
    required this.stop,
    required this.options,
  });

  final TraceSession session;
  final TraceScene scene;
  final String? item;
  final int duration;
  final bool disabled;
  final VoidCallback stop;
  final ValueChanged<_TimerAction> options;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: traceForest,
      borderRadius: BorderRadius.circular(22),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            spacing: 7,
            children: [
              const TraceDot(0xffe2bd84),
              Expanded(
                child: Text(
                  item == null ? scene.name : '${scene.name} · $item',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              PopupMenuButton<_TimerAction>(
                tooltip: '${scene.name}计时操作',
                enabled: !disabled,
                iconColor: Colors.white,
                onSelected: options,
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: _TimerAction.adjust,
                    child: Text('修正后结束'),
                  ),
                  PopupMenuItem(
                    value: _TimerAction.discard,
                    child: Text('丢弃本次计时'),
                  ),
                ],
              ),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              traceHms(duration),
              style: const TextStyle(
                color: Color(0xfffaf5e4),
                fontSize: 43,
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()],
                height: 1.08,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '计时中 · ${traceTime(session.startedMs)} 开始',
            style: const TextStyle(color: Color(0xffdce9dd)),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            spacing: 6,
            children: [
              TextButton(
                onPressed: disabled
                    ? null
                    : () => options(_TimerAction.details),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xfff3f2e8),
                ),
                child: const Text('本次详情'),
              ),
              FilledButton.icon(
                onPressed: disabled ? null : stop,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xfff2e5c7),
                  foregroundColor: traceInk,
                ),
                icon: const Icon(Icons.stop_rounded),
                label: const Text('结束'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
