import 'package:flutter_riverpod/flutter_riverpod.dart';
// 应用配置 (窗口, 托盘等)
// ui相关.
import 'package:flutter/material.dart';
import 'package:northstar/app/app.dart';
import 'package:northstar/app/bootstrap.dart';
import 'package:northstar/services/app_service/window_service.dart';
import 'package:northstar/services/cert_trust.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await CertTrust.init();
  // 预载持久化配置：必须在 runApp 之前完成，否则首个接口请求会带着
  // 默认配置发出（连错端口），启动后必须手动刷新才能拿到数据。
  final container = await bootstrap();
  await initWindow();
  runApp(UncontrolledProviderScope(container: container, child: const MyApp()));
}
