// ignore_for_file: unused_result

import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/profile/second_page/data/models/action_info.dart';
import 'package:torrid/features/profile/second_page/data/providers/backup_service.dart';
import 'package:torrid/features/profile/second_page/data/providers/sync_service.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';

part 'status_provider.g.dart';

// 数据传输页的响应式数据.
// TODO: 同步到本地时, 有些慢, 根据图片数的下载回调来做个进度条吧.
// TODO: 同步到本地时, 有些慢, 根据图片数的下载回调来做个进度条吧.
@riverpod
class DataService extends _$DataService {
  @override
  Map build() {
    return {"connected": false, "isLoading": false};
  }

  // 网络请求测试方法.
  Future<void> testNetwork() async {
    bool connected_ = false;
    final resp = await ref.watch(fetcherProvider(path: "/util/test").future);
    if (resp != null && resp.statusCode == 200) {
      connected_ = true;
    }
    state = {...state, 'connected': connected_};
  }

  Future<void> loadWithFunc(Function func) async {
    state = {...state, "isLoading": true};
    await func();
    state = {...state, "isLoading": false};
  }
}

// 各个按钮的信息.
@riverpod
List<ActionInfo> actionInfos(ActionInfosRef ref) {
  return <ActionInfo>[
    // 同步到本地
    ActionInfo(
      icon: Icons.download,
      label: "同步所有",
      action: () async {
        await ref.refresh(syncBookletProvider.future);
        await ref.refresh(syncEssayProvider.future);
      },
      highlighted: true,
    ),
    ActionInfo(
      icon: Icons.check_circle,
      label: "同步打卡",
      action: () async {
        await ref.refresh(syncBookletProvider.future);
      },
    ),
    ActionInfo(
      icon: Icons.note,
      label: "同步随笔",
      action: () async {
        await ref.refresh(syncEssayProvider.future);
      },
    ),
    ActionInfo(icon: Icons.label, label: "同步藏品", action: () async {}),

    // 备份到PC
    ActionInfo(
      icon: Icons.upload,
      label: "备份所有",
      action: () async {
        await ref.refresh(backupBookletProvider.future);
        await ref.refresh(backupEssayProvider.future);
      },
      highlighted: true,
    ),
    ActionInfo(
      icon: Icons.upload_file,
      label: "备份打卡",
      action: () async {
        await ref.refresh(backupBookletProvider.future);
      },
    ),
    ActionInfo(
      icon: Icons.upload,
      label: "备份随笔",
      action: () async {
        await ref.refresh(backupEssayProvider.future);
      },
    ),
    ActionInfo(icon: Icons.label, label: "备份藏品", action: () async {}),
  ];
}
