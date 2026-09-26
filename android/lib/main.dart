import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:torrid/app/app.dart';
import 'package:torrid/core/services/network/cert_trust.dart';

void main() async {
  // // 确保Flutter绑定初始化
  WidgetsFlutterBinding.ensureInitialized();

  // 全应用锁定竖屏：画廊内的媒体旋转由页面自身处理，不依赖系统旋转
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // 初始化自签证书信任
  await CertTrust.init();

  runApp(ProviderScope(child: const MyApp()));
}
