import 'dart:io';

import 'package:torrid/services/debug/logging_service.dart';
import 'package:torrid/services/io/io_service.dart';
import 'package:torrid/services/network/apiclient_handler.dart';

import 'package:torrid/features/booklet/services/booklet_hive_service.dart';
import 'package:torrid/shared/models/network_status.dart';

class BookletService {
  static Future<void> syncBooklet({NetworkStatus? status}) async {
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

  static Future<void> backupBooklet({NetworkStatus? status}) async {
    try {
      final data = BookletHiveService.packUp();
      // 获取外部存储目录
      final externalDir = await IoService.externalStorageDir;
      if (externalDir == null) {
        throw Exception("无法获取外部存储目录");
      }
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
}
