import 'package:flutter/material.dart';
import 'package:northstar/services/io/io_service.dart';
import 'package:northstar/features/home/models/directory_item.dart';
import 'package:path/path.dart' as path;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'directories_provider.g.dart';

@riverpod
List<DirectoryItem> appDirectories(AppDirectoriesRef ref){
  return [
    DirectoryItem(
      icon: Icons.folder_open_rounded,
      title: "数据存储目录",
      path: path.join(IoService.appDir, "static"),
      color: Colors.orangeAccent,
    ),
    DirectoryItem(
      icon: Icons.logo_dev_rounded,
      title: "日志目录",
      path: path.join(IoService.appDir, "logging"),
      color: Colors.blueAccent,
    ),
    DirectoryItem(
      icon: Icons.settings_backup_restore_rounded,
      title: "待定",
      path: path.join(IoService.appDir, "static/essay"),
      color: Colors.greenAccent,
    ),
    DirectoryItem(
      icon: Icons.assessment_outlined,
      title: "资源库",
      path: path.join(IoService.appDir, "static/essay"),
      color: Colors.purpleAccent,
    ),
  ];
}