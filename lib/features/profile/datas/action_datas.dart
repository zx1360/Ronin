import 'package:flutter/material.dart';
import 'package:torrid/features/booklet/services/booklet_service.dart';
import 'package:torrid/features/essay/services/essay_service.dart';

class ActionInfo {
  final IconData icon;
  final String label;
  final Future<void> Function() action;
  final bool highlighted;

  ActionInfo({
    required this.icon,
    required this.label,
    required this.action,
    this.highlighted = false,
  });
}

class InfoDatas {
  static List<ActionInfo> get infos => [
    // 同步到本地
    ActionInfo(
      icon: Icons.download,
      label: "同步所有",
      action: () async {
        await BookletService.syncBooklet();
        await EssayService.syncEssay();
      },
      highlighted: true,
    ),
    ActionInfo(
      icon: Icons.check_circle,
      label: "同步打卡",
      action: BookletService.syncBooklet,
    ),
    ActionInfo(icon: Icons.note, label: "同步随笔", action: EssayService.syncEssay),
    ActionInfo(icon: Icons.label, label: "同步藏品", action: () async {}),

    // 备份到PC
    ActionInfo(
      icon: Icons.upload,
      label: "备份所有",
      action: () async {
        await BookletService.backupBooklet();
        await EssayService.backupEssay();
      },
      highlighted: true,
    ),
    ActionInfo(
      icon: Icons.upload_file,
      label: "备份打卡",
      action: BookletService.backupBooklet,
    ),
    ActionInfo(
      icon: Icons.upload,
      label: "备份随笔",
      action: EssayService.backupEssay,
    ),
    ActionInfo(icon: Icons.label, label: "备份藏品", action: () async {}),
  ];
}
