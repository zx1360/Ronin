import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/core/modals/snack_bar.dart';
import 'package:torrid/features/profile/second_page/data/models/transfer_progress.dart';
import 'package:torrid/features/profile/second_page/data/services/transfer_controller.dart';

import 'trace_catalog_page.dart';
import 'trace_desk.dart';
import 'trace_history.dart';
import 'trace_store.dart';
import 'trace_timing.dart';
import 'trace_ui.dart';

class TracePage extends ConsumerStatefulWidget {
  const TracePage({super.key});

  @override
  ConsumerState<TracePage> createState() => _TracePageState();
}

class _TracePageState extends ConsumerState<TracePage> {
  bool _syncing = false;
  bool _recovering = true;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: () => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await traceAction(context, () async {
        await recoverTrace(
          context,
          ref.read(traceStoreProvider),
          importedOnly: true,
        );
      });
      if (mounted) setState(() => _recovering = false);
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _sync() async {
    if (_syncing || _recovering) return;
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
      if (mounted) displaySnackBar(context, traceError(error));
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(traceDataProvider);
    final store = ref.watch(traceStoreProvider);
    return Theme(
      data: traceTheme(Theme.of(context)),
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('时迹'),
            actions: [
              IconButton(
                tooltip: '管理场景与标签',
                icon: const Icon(Icons.tune_rounded),
                onPressed: () => Navigator.of(
                  context,
                ).push(traceRoute<void>(const TraceCatalogPage())),
              ),
              IconButton(
                tooltip: _syncing ? '正在同步' : '同步与备份',
                onPressed: _syncing || _recovering ? null : _sync,
                icon: _syncing
                    ? const SizedBox.square(
                        dimension: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_sync_outlined),
              ),
              const SizedBox(width: 6),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xffedeee5),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const TabBar(
                    padding: EdgeInsets.all(3),
                    dividerHeight: 0,
                    labelColor: traceForest,
                    unselectedLabelColor: Color(0xff596258),
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: tracePanel,
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    tabs: [
                      Tab(text: '计时'),
                      Tab(text: '回顾'),
                    ],
                  ),
                ),
              ),
            ),
          ),
          body: data.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(
              child: TextButton.icon(
                onPressed: () => ref.invalidate(traceDataProvider),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('时迹读取失败，重试'),
              ),
            ),
            data: (data) => TabBarView(
              children: [
                TraceDesk(data: data, store: store),
                TraceHistory(data: data),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
