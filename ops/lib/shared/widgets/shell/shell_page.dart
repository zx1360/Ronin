import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

import 'package:northstar/app/routes.dart';
import 'package:northstar/core/providers/ai/ai_providers.dart';
import 'package:northstar/core/providers/comix/comix_providers.dart';
import 'package:northstar/core/providers/ops/core_services_provider.dart';
import 'package:northstar/core/providers/ops/runtime_process_provider.dart';
import 'package:northstar/domain/ops/models/window_geometry.dart';
import 'package:northstar/shared/widgets/shell/side_navbar/side_navbar.dart';
import 'package:northstar/shared/widgets/shell/titlebar/titlebar.dart';

/// 漫画资源页在 [routes] 中的分支索引。
final int _comixBranchIndex = routes.indexWhere(
  (route) => route.path == '/comix',
);

/// AI 媒体处理页在 [routes] 中的分支索引。
final int _aiBranchIndex = routes.indexWhere((route) => route.path == '/ai');

class ShellPage extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;
  const ShellPage({super.key, required this.navigationShell});

  @override
  ConsumerState<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends ConsumerState<ShellPage> with WindowListener {
  final _systemTray = SystemTray();
  final _menu = Menu();
  bool _isTrayInitialized = false;
  bool _isMaximized = false;

  /// 缩放窗口时 onWindowResize 会连续触发，落盘必须防抖。
  Timer? _geometrySaveTimer;

  @override
  void initState() {
    super.initState();
    _initSystemTray();
    _initCloseBehavior();
    windowManager.addListener(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // 建窗时的最大化可能早于监听注册，首帧后补一次同步。
      _syncMaximizedState();
      _syncComixPageActive(widget.navigationShell.currentIndex);
    });
  }

  @override
  void didUpdateWidget(ShellPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navigationShell.currentIndex !=
        widget.navigationShell.currentIndex) {
      _syncComixPageActive(widget.navigationShell.currentIndex);
    }
  }

  /// indexedStack 的分支常驻不销毁，页面可见性只能由分支索引驱动：
  /// 切走页面时必须停掉它的轮询（dispose 不会触发）。
  void _syncComixPageActive(int currentIndex) {
    ref
        .read(comixBoardProvider.notifier)
        .setPageActive(currentIndex == _comixBranchIndex);
    ref
        .read(aiBoardProvider.notifier)
        .setPageActive(currentIndex == _aiBranchIndex);
  }

  @override
  void dispose() {
    _geometrySaveTimer?.cancel();
    windowManager.removeListener(this);
    if (_isTrayInitialized) {
      _systemTray.destroy();
    }
    super.dispose();
  }

  /// 最大化/还原按钮的图标跟随窗口事件，用户从系统菜单或双击标题栏切换时也要跟上。
  Future<void> _syncMaximizedState() async {
    final maximized = await windowManager.isMaximized();
    if (!mounted) return;
    if (maximized != _isMaximized) {
      setState(() => _isMaximized = maximized);
    }
  }

  /// 更新最大化标记并排队落盘：事件随后的尺寸变化会被防抖合并掉。
  void _setMaximized(bool maximized) {
    if (!mounted) return;
    if (maximized != _isMaximized) {
      setState(() => _isMaximized = maximized);
    }
    _scheduleGeometrySave();
  }

  void _scheduleGeometrySave() {
    _geometrySaveTimer?.cancel();
    _geometrySaveTimer = Timer(
      const Duration(milliseconds: 400),
      _saveWindowGeometry,
    );
  }

  /// 保存窗口几何。最大化时 getSize() 返回的是被拉满的屏幕尺寸，
  /// 存下来会把还原尺寸撑到整屏，因此最大化状态下只更新标记、保留原尺寸。
  Future<void> _saveWindowGeometry() async {
    _geometrySaveTimer?.cancel();
    _geometrySaveTimer = null;
    if (!mounted) return;

    final repository = ref.read(opsPersistenceRepositoryProvider);
    final previous = repository.windowGeometry ?? WindowGeometry.defaults();
    try {
      final maximized = await windowManager.isMaximized();
      final size = maximized ? null : await windowManager.getSize();
      await repository.saveWindowGeometry(
        previous.copyWith(
          width: size?.width,
          height: size?.height,
          maximized: maximized,
        ),
      );
    } catch (_) {
      // 窗口已销毁时读不到尺寸：放弃本次落盘，不影响退出流程。
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          SideNavbar(navigationShell: widget.navigationShell),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(child: widget.navigationShell),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: TitleBar(isMaximized: _isMaximized),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 系统托盘初始化
  Future<void> _initSystemTray() async {
    try {
      await _systemTray.initSystemTray(
        iconPath: "assets/icons/six.ico",
        toolTip: "northstar北极星",
      );
      await _menu.buildFrom([
        MenuItemLabel(
          label: "退出",
          onClicked: (item) async {
            await windowManager.close();
          },
        ),
      ]);
      _systemTray.setContextMenu(_menu);

      // 注册事件
      _systemTray.registerSystemTrayEventHandler((eventName) async {
        switch (eventName) {
          case kSystemTrayEventClick:
            await windowManager.show();
            break;
          case kSystemTrayEventRightClick:
            await _systemTray.popUpContextMenu();
            break;
        }
      });

      // 标记初始化成功
      _isTrayInitialized = true;
    } catch (error) {
      // 托盘初始化失败不能中断启动，也不能把异常抛出 initState 的异步链；
      // 保持 _isTrayInitialized=false，退出时不会再尝试销毁不存在的图标。
      debugPrint('托盘初始化失败: $error');
    }
  }

  Future<void> _initCloseBehavior() async {
    await windowManager.setPreventClose(true);
  }

  @override
  void onWindowMaximize() => _setMaximized(true);

  @override
  void onWindowUnmaximize() => _setMaximized(false);

  @override
  void onWindowResize() => _scheduleGeometrySave();

  @override
  Future<void> onWindowClose() async {
    // 退出流程可能弹出确认框并被取消，但几何信息先落盘无害。
    await _saveWindowGeometry();

    final runtimeController = ref.read(
      runtimeProcessControllerProvider.notifier,
    );

    if (!mounted) {
      return;
    }

    if (runtimeController.hasRunningTasks) {
      final shouldTerminate = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('仍有任务在运行'),
          content: const Text('检测到仍有子进程在运行，退出前是否终止所有任务？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消退出'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('终止并退出'),
            ),
          ],
        ),
      );

      if (shouldTerminate != true) {
        return;
      }

      await runtimeController.terminateAllRunningProcesses();
    }

    if (_isTrayInitialized) {
      await _systemTray.destroy();
      _isTrayInitialized = false;
    }

    await windowManager.destroy();
  }
}
