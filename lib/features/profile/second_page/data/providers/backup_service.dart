import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/booklet/providers/routine_notifier_provider.dart';
import 'package:torrid/features/essay/providers/essay_notifier_provider.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';
import 'package:torrid/services/debug/logging_service.dart';
import 'package:torrid/services/io/io_service.dart';

part 'backup_service.g.dart';

@riverpod
Future<void> backupBooklet(BackupBookletRef ref) async {
  try {
    final notifier = ref.read(routineServiceProvider.notifier);
    final data = notifier.packUp();
    // 获取外部存储目录
    final externalDir = await IoService.externalStorageDir;
    final files = notifier
        .getImgsPath()
        .map((path) => File("${externalDir.path}/$path"))
        .toList();

    final resp = await ref.read(
      senderProvider(
        path: "/api/user-data/backup/booklet",
        jsonData: data,
        files: files,
      ).future,
    );
    if (resp?.statusCode != 200) {
      AppLogger().error("backupBooklet失败.");
    }
  } catch (e) {
    AppLogger().error("backupBooklet出错: $e");
  }
}

@riverpod
Future<void> backupEssay(BackupEssayRef ref) async {
  try {
    final notifier = ref.read(essayServiceProvider.notifier);
    final data = notifier.packUp();
    final externalDir = await IoService.externalStorageDir;
    final files = notifier
        .getImgsPath()
        .map((path) => File("${externalDir.path}/$path"))
        .toList();

    final resp = await ref.read(
      senderProvider(
        path: "/api/user-data/backup/essay",
        jsonData: data,
        files: files,
      ).future,
    );
    if (resp?.statusCode != 200) {
      AppLogger().error("backupEssay失败.");
    }
  } catch (e) {
    AppLogger().error("backupEssay出错: $e");
  }
}
