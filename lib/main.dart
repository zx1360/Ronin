// web服务器.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:northstar/_server/myserver.dart';
import 'package:northstar/services/io/io_service.dart';
// 应用配置 (窗口, 托盘等)
// ui相关.
import 'package:flutter/material.dart';
import 'package:northstar/app/app.dart';
import 'package:northstar/services/app_service/window_service.dart';


void main(List<String> args) async {
  // 初始化目录, 创建需要的目录结构.
  await IoService.initDirectories();
  // 根据参数选择启动模式.
  // 开发时: flutter run -d windows --dart-define=nas=true
  // exe: northstar.exe --nas=true

  // 如果是nas环境, 只启动web服务而无ui.
  if (const String.fromEnvironment("nas").isNotEmpty) {
    final server = MyServer();
    await server.start(port: 9527);
    await Future.wait([]);
  }
  // 带ui的桌面运行环境.
  else {
    WidgetsFlutterBinding.ensureInitialized();
    // 初始化窗体配置 初始化系统托盘
    await initWindow();
    
    runApp(ProviderScope(child: MyApp()));
  }
}
