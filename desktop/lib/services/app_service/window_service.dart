import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';


Future<void> initWindow()async{
  await windowManager.ensureInitialized();
    // 窗口属性
    WindowOptions windowOptions = WindowOptions(
      center: true,
      title: "northstar 北极星",
      size: const Size(916, 616),
      backgroundColor: Colors.transparent,  //MaterialApp后面的背景颜色设为透明.
      titleBarStyle: TitleBarStyle.hidden 
    );
    if (Platform.isWindows) {
      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.setResizable(false);
        // TODO: 可添加一系列on监听事件 (关闭/获得焦点等.)
        //      获取窗口的各种信息.
        
        await windowManager.show();
        await windowManager.focus();
      });
    }
}

