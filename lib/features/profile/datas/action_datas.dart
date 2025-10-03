import 'package:flutter/material.dart';
import 'package:torrid/features/booklet/services/booklet_service.dart';

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
      action: ()async{},
      highlighted: true,
    ),
    ActionInfo(
      icon: Icons.check_circle,
      label: "同步打卡",
      action: BookletService.syncBooklet,
    ),
    ActionInfo(
      icon: Icons.note,
      label: "同步随笔",
      action: ()async{},
    ),
    ActionInfo(
      icon: Icons.label,
      label: "同步藏品",
      action: ()async{},
    ),

    // 更新到PC
    ActionInfo(
      icon: Icons.upload,
      label: "更新所有",
      action: ()async{},
      highlighted: true,
    ),
    ActionInfo(
      icon: Icons.upload_file,
      label: "更新打卡",
      action: BookletService.backupBooklet,
    ),
    ActionInfo(
      icon: Icons.upload,
      label: "更新随笔",
      action: ()async{},
    ),
    ActionInfo(
      icon: Icons.label,
      label: "更新藏品",
      action: ()async{},
    ),
  ];
}
