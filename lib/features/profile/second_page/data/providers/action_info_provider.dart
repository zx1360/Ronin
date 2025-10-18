import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/profile/second_page/data/models/action_info.dart';

part 'action_info_provider.g.dart';

@riverpod
List<ActionInfo> actionInfos(ActionInfosRef ref) {
  return <ActionInfo>[
    // 同步到本地
    ActionInfo(
      icon: Icons.download,
      label: "同步所有",
      action: () async {
        // await BookletService.syncBooklet();
        // await EssayService.syncEssay();
      },
      highlighted: true,
    ),
    ActionInfo(
      icon: Icons.check_circle,
      label: "同步打卡",
      action: ()async{
        // BookletService.syncBooklet
        },
    ),
    ActionInfo(icon: Icons.note, label: "同步随笔", action: ()async{
      // EssayService.syncEssay
    }),
    ActionInfo(icon: Icons.label, label: "同步藏品", action: () async {}),

    // 备份到PC
    ActionInfo(
      icon: Icons.upload,
      label: "备份所有",
      action: () async {
        // await BookletService.backupBooklet();
        // await EssayService.backupEssay();
      },
      highlighted: true,
    ),
    ActionInfo(
      icon: Icons.upload_file,
      label: "备份打卡",
      action: ()async{
        // BookletService.backupBooklet
      },
    ),
    ActionInfo(
      icon: Icons.upload,
      label: "备份随笔",
      action: ()async{
        // EssayService.backupEssay
      },
    ),
    ActionInfo(icon: Icons.label, label: "备份藏品", action: () async {}),
  ];
}
