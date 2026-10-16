import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:torrid/app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 全应用锁定竖屏
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(ProviderScope(child: const MyApp()));
}
