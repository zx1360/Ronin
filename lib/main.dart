import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:torrid/app/app.dart';
import 'package:torrid/core/services/io/io_service.dart';

import 'package:torrid/features/booklet/services/booklet_hive_service.dart';
import 'package:torrid/features/essay/services/essay_hive_service.dart';
import 'package:torrid/features/others/comic/services/comic_hive_service.dart';
import 'package:torrid/features/others/tuntun/services/tuntun_hive_service.dart';

void main() async {
  // // 1.确保Flutter绑定初始化
  WidgetsFlutterBinding.ensureInitialized();
  // // 2.其他初始化
  await IoService.initDirs();
  await Hive.initFlutter();

  await Future.wait([
    BookletHiveService.init(),
    EssayHiveService.init(),
    TuntunHiveService.init(),
    ComicHiveService.init(),
  ]);

  // TODO: 可以更改为最快速度显示启动页, 在其initState中初始化, 然后if(mouted)跳转首页.
  runApp(ProviderScope(child: const MyApp()));
}
