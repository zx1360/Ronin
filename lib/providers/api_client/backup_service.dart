import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'backup_service.g.dart';

@riverpod
Future<void> backupBooklet()async{
  try {
      final data = BookletHiveService.packUp();
      // 获取外部存储目录
      final externalDir = await IoService.externalStorageDir;
      final files = BookletHiveService.getImgsPath()
          .map((path) => File("${externalDir.path}/$path"))
          .toList();

      final resp = await ApiclientHandler.send(
        path: "/backup/booklet",
        status: status,
        jsonData: data,
        files: files,
      );
      if (resp?.statusCode != 200) {
        throw Exception("backupBooklet失败.");
      }
    } catch (e) {
      throw Exception("backupBooklet出错: $e");
    }
}

@riverpod
Future<void> backupEssay() async {
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
