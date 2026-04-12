import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

import 'package:northstar/shared/widgets/shell/side_navbar/side_navbar.dart';
import 'package:northstar/shared/widgets/shell/titlebar/titlebar.dart';

class ShellPage extends StatefulWidget {
  final StatefulNavigationShell navigationShell;
  const ShellPage({
    super.key,
    required this.navigationShell,
  });

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  final _systemTray = SystemTray();
  final _menu = Menu();
  bool _isTrayInitialized = false;

  @override
  void initState() {
    super.initState();
    _initSystemTray();
  }

  @override
  void dispose() {
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
            await _systemTray.destroy();
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
            case kSystemTrayEventRightClick:
            await _systemTray.popUpContextMenu();
        }
      });

      // 标记初始化成功
      _isTrayInitialized = true;
    } catch (error) {
      throw Exception("托盘初始化失败: $error");
    }
  }
}
