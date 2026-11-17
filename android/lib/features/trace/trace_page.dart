import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/app/theme/theme_book.dart';
import 'package:torrid/core/modals/snack_bar.dart';
import 'package:torrid/core/widgets/async_value_widget/async_value_widget.dart';
import 'package:torrid/features/profile/second_page/data/models/transfer_progress.dart';
import 'package:torrid/features/profile/second_page/data/services/transfer_controller.dart';

import 'trace_catalog_page.dart';
import 'trace_clock.dart';
import 'trace_data.dart';
import 'trace_history.dart';
import 'trace_session_editor.dart';
import 'trace_store.dart';
import 'trace_timing.dart';

class TracePage extends ConsumerStatefulWidget {
  const TracePage({super.key});

  @override
  ConsumerState<TracePage> createState() => _TracePageState();
}

class _TracePageState extends ConsumerState<TracePage> {
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(
          traceAction(context, () async {
            await recoverTrace(
              context,
              ref.read(traceStoreProvider),
              importedOnly: true,
            );
          }),
        );
      }
    });
  }

  Future<void> _sync() async {
    setState(() => _syncing = true);
    final store = ref.read(traceStoreProvider);
    Future<TransferResult> transfer() => ref
        .read(transferControllerProvider.notifier)
        .execute(type: TransferType.sync, target: TransferTarget.trace);
    try {
      var result = await transfer();
      if (!mounted) return;
      if (await recoverTrace(context, store, importedOnly: true) && mounted) {
        result = await transfer();
      }
      if (mounted) displaySnackBar(context, result.message);
    } catch (error) {
      if (mounted) displaySnackBar(context, '时迹同步失败 · $error');
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(traceStoreProvider);
    final scheme = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('时迹'),
          bottom: AppTheme.appBarTabs(
            scheme,
            tabs: const [
              Tab(text: '计时'),
              Tab(text: '回顾'),
            ],
          ),
          actions: [
            IconButton(
              tooltip: _syncing ? '正在同步' : '同步与备份',
              onPressed: _syncing ? null : _sync,
              icon: _syncing
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: scheme.onPrimary,
                      ),
                    )
                  : const Icon(Icons.cloud_sync_outlined),
            ),
            IconButton(
              tooltip: '场景与标签',
              icon: const Icon(Icons.tune_rounded),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const TraceCatalogPage(),
                ),
              ),
            ),
          ],
        ),
        body: AsyncValueWidget<TraceData>(
          asyncValue: ref.watch(traceDataProvider),
          dataBuilder: (data) => TabBarView(
            children: [
              _TimerPage(data: data, store: store),
              TraceHistory(data: data, store: store),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimerPage extends StatelessWidget {
  const _TimerPage({required this.data, required this.store});

  final TraceData data;
  final TraceStore store;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeIds = data.active.map((s) => s.sceneId).toSet();
    final scenes = data.scenes.where((s) => !s.archived).toList();
    return ListView(
      key: const PageStorageKey('trace-timer'),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        _TimerHeader(data: data),
        if (data.active.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('进行中', style: theme.textTheme.titleMedium),
          _RunningTimers(data: data, store: store),
        ],
        const SizedBox(height: 22),
        Text('我的场景', style: theme.textTheme.titleMedium),
        const SizedBox(height: 6),
        if (scenes.isEmpty) const ListTile(title: Text('可从右上角添加场景。')),
        for (final scene in scenes)
          Card(
            elevation: 0,
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              leading: _SceneMark(
                color: Color(scene.color),
                icon: Icons.timelapse,
              ),
              title: Text(scene.name),
              subtitle: Text(
                '累计 ${traceDuration(data.totals.scenes[scene.id] ?? 0)}',
              ),
              trailing: activeIds.contains(scene.id)
                  ? const Text('计时中')
                  : FilledButton.tonalIcon(
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('开始'),
                      onPressed: () =>
                          traceAction(context, () => store.start(scene)),
                    ),
            ),
          ),
      ],
    );
  }
}

class _TimerHeader extends StatelessWidget {
  const _TimerHeader({required this.data});

  final TraceData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 14, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.primaryContainer, colors.surfaceContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('累计投入', style: theme.textTheme.labelLarge),
                const SizedBox(height: 4),
                Text(
                  traceDuration(data.totals.all),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontFeatures: [const FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${data.history.length} 次记录',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const _Cabin(),
        ],
      ),
    );
  }
}

class _Cabin extends StatelessWidget {
  const _Cabin();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: SizedBox(
        width: 88,
        height: 80,
        child: Stack(
          children: [
            Positioned(
              top: 4,
              right: 4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.secondaryContainer,
                  shape: BoxShape.circle,
                ),
                child: const SizedBox.square(dimension: 65),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Icon(
                Icons.wb_sunny_outlined,
                color: colors.secondary,
                size: 18,
              ),
            ),
            Positioned(
              bottom: 8,
              left: 2,
              child: Icon(
                Icons.park_outlined,
                color: colors.secondary,
                size: 34,
              ),
            ),
            Positioned(
              bottom: 5,
              right: 6,
              child: Icon(Icons.cabin_rounded, color: colors.primary, size: 54),
            ),
          ],
        ),
      ),
    );
  }
}

class _SceneMark extends StatelessWidget {
  const _SceneMark({required this.color, required this.icon});

  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(9),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Icon(icon, color: color, size: 22),
  );
}

class _RunningTimers extends StatefulWidget {
  const _RunningTimers({required this.data, required this.store});

  final TraceData data;
  final TraceStore store;

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
    final sample = await TraceClock.read();
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
    final theme = Theme.of(context);
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
      children: [
        for (final session in widget.data.active)
          Card(
            elevation: 0,
            margin: const EdgeInsets.only(top: 8),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _SceneMark(
                        color: Color(
                          widget.data.sceneById[session.sceneId]!.color,
                        ),
                        icon: Icons.hourglass_top_rounded,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.data.sceneById[session.sceneId]!.name,
                              style: theme.textTheme.titleMedium,
                            ),
                            if (widget.data.itemById[session.itemId]
                                case final item?)
                              Text(item.name),
                            Text(
                              traceHms(clock.durationMs(session)),
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontFeatures: [
                                  const FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      AnimatedSlide(
                        offset:
                            !MediaQuery.disableAnimationsOf(context) &&
                                delta ~/ 1000 % 2 == 1
                            ? const Offset(0, -0.12)
                            : Offset.zero,
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeInOut,
                        child: ExcludeSemantics(
                          child: Icon(
                            Icons.coffee_outlined,
                            color: theme.colorScheme.primary,
                            size: 30,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        TextButton.icon(
                          onPressed: () => editTraceSession(
                            context,
                            widget.store,
                            widget.data,
                            session,
                          ),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('补充详情'),
                        ),
                        FilledButton.icon(
                          onPressed: () => traceAction(
                            context,
                            () => widget.store.stop(session),
                          ),
                          icon: const Icon(Icons.stop_rounded),
                          label: const Text('结束'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
