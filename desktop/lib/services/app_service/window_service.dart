import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

Future<void> initWindow() async {
  await windowManager.ensureInitialized();
  WindowOptions windowOptions = WindowOptions(
    center: true,
    title: "northstar 北极星",
    size: const Size(1024, 688),
    backgroundColor: Colors.transparent, //MaterialApp后面的背景颜色设为透明.
    titleBarStyle: TitleBarStyle.hidden,
  );
  if (Platform.isWindows) {
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.setResizable(false);
      await windowManager.show();
      await windowManager.focus();
    });
  }
}
