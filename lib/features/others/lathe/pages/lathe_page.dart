import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/countdown_timer_provider.dart';
import '../services/lathe_foreground_service.dart';
import '../services/lathe_notification_service.dart';
import '../widgets/countdown_timer_card.dart';
import '../widgets/timer_edit_dialog.dart';

class LathePage extends ConsumerStatefulWidget {
  const LathePage({super.key});

  @override
  ConsumerState<LathePage> createState() => _LathePageState();
}

class _LathePageState extends ConsumerState<LathePage> with WidgetsBindingObserver {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // 从后台恢复时同步状态
      ref.read(countdownTimersProvider.notifier).syncOnResume();
    }
  }

  Future<void> _initializeServices() async {
    // 初始化通知服务
    await LatheNotificationService.instance.initialize();
    await LatheNotificationService.instance.requestPermission();
    
    // 初始化前台服务
    await LatheForegroundService.instance.initialize();
    
    setState(() {
      _isInitialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(countdownTimersProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('循环倒计时'),
        centerTitle: true,
        actions: [
          // 显示运行状态
          if (state.hasRunningTimers)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 8,
                    height: 8,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  SizedBox(width: 6),
                  Text(
                    '运行中',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF4CAF50),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: !_isInitialized
          ? const Center(child: CircularProgressIndicator())
          : state.timers.isEmpty
              ? _buildEmptyState(colorScheme)
              : _buildTimerList(state),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _onAddTimer,
        icon: const Icon(Icons.add),
        label: const Text('添加倒计时'),
      ),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.timer_off_outlined,
            size: 80,
            color: colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            '还没有倒计时',
            style: TextStyle(
              fontSize: 18,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击下方按钮添加一个新的倒计时',
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.outline,
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  /// 构建倒计时列表
  Widget _buildTimerList(CountdownTimersState state) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 100),
      itemCount: state.timers.length,
      itemBuilder: (context, index) {
        final timer = state.timers[index];
        return CountdownTimerCard(
          timer: timer,
          onStart: () => ref.read(countdownTimersProvider.notifier).startTimer(timer.id),
          onStop: () => _onStopTimer(timer.id, timer.name),
          onRestart: () => ref.read(countdownTimersProvider.notifier).restartTimer(timer.id),
          onEdit: () => _onEditTimer(timer.id, timer.name, timer.totalSeconds),
          onDelete: () => _onDeleteTimer(timer.id, timer.name),
        );
      },
    );
  }

  /// 添加倒计时
  Future<void> _onAddTimer() async {
    final result = await showTimerEditDialog(context);
    if (result == null) return;

    ref.read(countdownTimersProvider.notifier).addTimer(
      name: result['name'] as String,
      totalSeconds: result['totalSeconds'] as int,
    );
  }

  /// 编辑倒计时
  Future<void> _onEditTimer(String id, String name, int totalSeconds) async {
    final result = await showTimerEditDialog(
      context,
      initialName: name,
      initialSeconds: totalSeconds,
      isEditing: true,
    );
    if (result == null) return;

    ref.read(countdownTimersProvider.notifier).updateTimer(
      id: id,
      name: result['name'] as String,
      totalSeconds: result['totalSeconds'] as int,
    );
  }

  /// 终止倒计时
  Future<void> _onStopTimer(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认终止'),
        content: Text('确定要终止"$name"吗？倒计时将重置。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('终止'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ref.read(countdownTimersProvider.notifier).stopTimer(id);
    }
  }

  /// 删除倒计时
  Future<void> _onDeleteTimer(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除"$name"吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ref.read(countdownTimersProvider.notifier).removeTimer(id);
    }
  }
}
