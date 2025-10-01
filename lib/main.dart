import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/app/app.dart';


import 'package:torrid/core/services/storage/hive_service.dart';
import 'package:torrid/features/booklet/services/booklet_hive_service.dart';
import 'package:torrid/features/essay/services/essay_hive_service.dart';
import 'package:torrid/features/others/tuntun/services/tuntun_hive_service.dart';

void main() async {
  // // 1.确保Flutter绑定初始化
  WidgetsFlutterBinding.ensureInitialized();
  // // 2.其他初始化(Hive)
  await HiveService.init();
  
  await BookletHiveService.init();
  await EssayHiveService.init();
  await TuntunHiveService.init();

  runApp(ProviderScope(child: const MyApp()));
}

