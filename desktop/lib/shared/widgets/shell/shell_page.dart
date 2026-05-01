import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

import 'package:northstar/application/ops/providers/runtime_process_provider.dart';
import 'package:northstar/shared/widgets/shell/side_navbar/side_navbar.dart';
import 'package:northstar/shared/widgets/shell/titlebar/titlebar.dart';

class ShellPage extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;
  const ShellPage({
    super.key,
    required this.navigationShell,
  });

  @override
  ConsumerState<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends ConsumerState<ShellPage> with WindowListener {
  final _systemTray = SystemTray();
  final _menu = Menu();
  bool _isTrayInitialized = false;

  @override
  void initState() {
    super.initState();
    _initSystemTray();
    _initCloseBehavior();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    if (_isTrayInitialized) {
      _systemTray.destroy();
    }
    super.dispose();
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
                Positioned(top: 0,left: 0, right: 0,child: const TitleBar()),
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
        switch(eventName){
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
      throw Exception("托盘初始化失败: $error");
    }
  }

  Future<void> _initCloseBehavior() async {
    await windowManager.setPreventClose(true);
  }

  @override
  Future<void> onWindowClose() async {
    final runtimeController = ref.read(runtimeProcessControllerProvider.notifier);

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
