import 'dart:io';

import 'package:flutter/material.dart';
import 'package:northstar/domain/ops/models/window_geometry.dart';
import 'package:window_manager/window_manager.dart';

/// 创建主窗口：可缩放/可最大化，并按上次退出时保存的尺寸与最大化状态还原。
///
/// [geometry] 为 null（首次启动或文件损坏）时使用默认尺寸。
Future<void> initWindow({WindowGeometry? geometry}) async {
  await windowManager.ensureInitialized();
  final restored = geometry ?? WindowGeometry.defaults();
  const minimumSize = Size(WindowGeometry.minWidth, WindowGeometry.minHeight);
  WindowOptions windowOptions = WindowOptions(
    center: true,
    title: "northstar 北极星",
    size: Size(restored.width, restored.height),
    minimumSize: minimumSize,
    backgroundColor: Colors.transparent, //MaterialApp后面的背景颜色设为透明.
    titleBarStyle: TitleBarStyle.hidden,
  );
  if (Platform.isWindows) {
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.setResizable(true);
      await windowManager.show();
      await windowManager.focus();
      // 只能放在 show() 之后：waitUntilReadyToShow 会先无条件 unmaximize 一次。
      if (restored.maximized) {
        await windowManager.maximize();
      }
    });
  }
}
