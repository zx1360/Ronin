import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:torrid/app/app.dart';
import 'package:torrid/core/services/network/cert_trust.dart';

void main() async {
  // // 确保Flutter绑定初始化
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化自签证书信任
  await CertTrust.init();

  runApp(ProviderScope(child: const MyApp()));
}
