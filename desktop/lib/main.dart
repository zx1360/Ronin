import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:northstar/app/app.dart';
import 'package:northstar/app/bootstrap.dart';
import 'package:northstar/services/app_service/window_service.dart';
import 'package:northstar/services/cert_trust.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await CertTrust.init();
  } catch (_) {
    // 证书资源缺失/无效时继续启动：自签 HTTPS 服务将无法通过校验，
    // 但本地 HTTP 模式与其余功能仍可用。
  }
  // 预载持久化配置：必须在 runApp 之前完成，否则首个接口请求会带着
  // 默认配置发出（连错端口），启动后必须手动刷新才能拿到数据。
  final container = await bootstrap();
  await initWindow();
  runApp(UncontrolledProviderScope(container: container, child: const MyApp()));
}
