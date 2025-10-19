import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sync_service.g.dart';

@riverpod
Future<void> syncBooklet()async{
  try {
      final resp = await ApiclientHandler.fetch(
        path: "/sync/booklet",
        status: status,
      );
      if (resp == null || resp.statusCode != 200) {
        AppLogger().error("syncBooklet出错");
      } else {
        await BookletHiveService.syncData(resp.data);
      }
    } catch (e) {
      throw Exception("syncBooklet出错: $e");
    }
}

@riverpod
Future<void> backupEssay()async{
  try {
      final data = EssayHiveService.packUp();
      // 获取外部存储目录
      final externalDir = await IoService.externalStorageDir;
      final files = EssayHiveService.getImgsPath()
          .map((path) => File("${externalDir.path}/$path"))
          .toList();

      final resp = await ApiclientHandler.send(
        path: "/backup/essay",
        jsonData: data,
        files: files,
      );
      if (resp?.statusCode != 200) {
        throw Exception("backupEssay失败.");
      } else {
        AppLogger().debug("222");
      }
    } catch (e) {
      throw Exception("backupEssay出错: $e");
    }
}