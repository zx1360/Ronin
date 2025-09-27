import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/app/app.dart';


import 'package:torrid/services__to-core/common/hive_service.dart';
import 'package:torrid/services__to-core/booklet/booklet_hive_service.dart';
import 'package:torrid/services__to-core/essay/essay_hive_service.dart';
import 'package:torrid/services__to-core/tuntun/tuntun_hive_service.dart';

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

