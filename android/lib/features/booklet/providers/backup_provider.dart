import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:torrid/features/booklet/providers/data_source_provider.dart';

part 'backup_provider.g.dart';

/// ============================================================================
/// 备份相关的 Providers
/// 提供数据的序列化和图片路径获取
/// ============================================================================

/// JSON 数据 Provider - 用于数据备份
@riverpod
Map<String, dynamic> backupJsonData(BackupJsonDataRef ref) {
  final sortedStyles = ref.watch(allStylesProvider)
    ..sort((a, b) => b.startDate.compareTo(a.startDate));
  final sortedRecords = ref.watch(allRecordsProvider)
    ..sort((a, b) => b.date.compareTo(a.date));

  final stylesJson = sortedStyles.map((item) => item.toJson()).toList();
  final recordsJson = sortedRecords.map((item) => item.toJson()).toList();

  return {
    "jsonData": jsonEncode({"styles": stylesJson, "records": recordsJson}),
  };
}

/// 图片路径 Provider - 获取所有任务图片的相对路径
@riverpod
List<String> taskImagePaths(TaskImagePathsRef ref) {
  final allStyles = ref.watch(allStylesProvider);
  final List<String> urls = [];
  
  for (final style in allStyles) {
    style.tasks
        .where((task) => task.image.isNotEmpty && task.image != '')
        .forEach((task) {
      final relativePath = task.image.startsWith("/")
          ? task.image.replaceFirst("/", "")
          : task.image;
      urls.add(relativePath);
    });
  }
  return urls;
}
