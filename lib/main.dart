import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:northstar/services/storage/prefs_service.dart';
// 应用配置 (窗口, 托盘等)
// ui相关.
import 'package:flutter/material.dart';
import 'package:northstar/app/app.dart';
import 'package:northstar/services/app_service/window_service.dart';


void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await PrefsService.prefs;
  await initWindow();
  runApp(const ProviderScope(child: MyApp()));
}
