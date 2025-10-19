// import 'dart:io';

// import 'package:torrid/services/debug/logging_service.dart';
// import 'package:torrid/services/io/io_service.dart';
// import 'package:torrid/providers/api_client/apiclient_handler.dart';
// import 'package:torrid/features/essay/services/essay_hive_service.dart';

// class EssayService {
//   // 同步essay数据到本地
//   static Future<void> syncEssay() async {
//     try {
//       final resp = await ApiclientHandler.fetch(path: "/sync/essay");
//       if (resp == null || resp.statusCode != 200) {
//         AppLogger().error("syncEssay失败");
//       } else {
//         await EssayHiveService.syncData(resp.data);
//       }
//     } catch (e) {
//       throw Exception("syncEssay出错: $e");
//     }
//   }

//   // 备份essay数据到pc
//   static Future<void> backupEssay() async {
//     try {
//       final data = EssayHiveService.packUp();
//       // 获取外部存储目录
//       final externalDir = await IoService.externalStorageDir;
//       final files = EssayHiveService.getImgsPath()
//           .map((path) => File("${externalDir.path}/$path"))
//           .toList();

//       final resp = await ApiclientHandler.send(
//         path: "/backup/essay",
//         jsonData: data,
//         files: files,
//       );
//       if (resp?.statusCode != 200) {
//         throw Exception("backupEssay失败.");
//       } else {
//         AppLogger().debug("222");
//       }
//     } catch (e) {
//       throw Exception("backupEssay出错: $e");
//     }
//   }
// }
