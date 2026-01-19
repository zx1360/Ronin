// ignore_for_file: unused_result

import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/profile/second_page/data/models/action_info.dart';
import 'package:torrid/features/profile/second_page/data/models/transfer_progress.dart';
import 'package:torrid/features/profile/second_page/data/providers/transfer_service.dart';

part 'status_provider.g.dart';

// 数据传输页的响应式数据.
// 支持并发传输、进度跟踪、重试机制

/// 获取传输操作的Provider引用
/// 返回一个函数，调用该函数会执行相应的传输操作并返回结果
typedef TransferAction = Future<TransferResult> Function();

// 各个按钮的信息.
@riverpod
List<ActionInfo> actionInfos(ActionInfosRef ref) {
  return <ActionInfo>[
    // 同步到本地
    ActionInfo(
      icon: Icons.download,
      label: "同步所有",
      action: () async {
        await ref.refresh(syncAllWithProgressProvider.future);
      },
      highlighted: true,
    ),
    ActionInfo(
      icon: Icons.check_circle,
      label: "同步打卡",
      action: () async {
        await ref.refresh(syncBookletWithProgressProvider.future);
      },
    ),
    ActionInfo(
      icon: Icons.note,
      label: "同步随笔",
      action: () async {
        await ref.refresh(syncEssayWithProgressProvider.future);
      },
    ),
    // ActionInfo(icon: Icons.label, label: "同步藏品", action: () async {}),

    // 备份到PC
    ActionInfo(
      icon: Icons.upload,
      label: "备份所有",
      action: () async {
        await ref.refresh(backupAllWithProgressProvider.future);
      },
      highlighted: true,
    ),
    ActionInfo(
      icon: Icons.upload_file,
      label: "备份打卡",
      action: () async {
        await ref.refresh(backupBookletWithProgressProvider.future);
      },
    ),
    ActionInfo(
      icon: Icons.upload,
      label: "备份随笔",
      action: () async {
        await ref.refresh(backupEssayWithProgressProvider.future);
      },
    ),
    // ActionInfo(icon: Icons.label, label: "备份藏品", action: () async {}),
  ];
}
