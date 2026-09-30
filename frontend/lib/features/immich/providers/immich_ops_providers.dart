import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/gallery/models/media_asset.dart';
import 'package:torrid/features/immich/providers/immich_providers.dart';

part 'immich_ops_providers.g.dart';

// 相册页(immich)批量操作流程层
//
// 负责"做什么、先后怎么调、结果如何": 选中项换算、是否需要用户补充输入、
// 具体调用序列与成功/失败结果都在这里; 弹窗控件、布局以及全部文案留在页面层,
// 页面只按这里给出的请求呈现输入, 并把输入回填。

// 操作种类与请求

/// 批量操作种类
enum ImmichBatchOp {
  /// 批量加标签
  addTags,

  /// 批量移除标签
  removeTags,

  /// 软删除
  delete,

  /// 恢复
  restore,

  /// 编辑备注
  message,

  /// 捆绑到主文件
  bundle,

  /// 解绑
  unbundle,
}

/// 校验不通过、直接拒绝操作的原因 (提示文案由页面给出)
enum ImmichOpRejection {
  /// 选中项都没有标签
  noTags,

  /// 捆绑至少需要两项可用媒体
  tooFewForBundle,
}

/// 操作前需要用户补充的输入; 具体弹窗与文案由页面决定
sealed class ImmichOpRequest {
  final ImmichBatchOp op;
  final List<String> mediaIds;

  const ImmichOpRequest({required this.op, required this.mediaIds});
}

/// 需要勾选标签; [restrictTo] 非空时只能从其中选择 (移除标签)
class ImmichTagPickRequest extends ImmichOpRequest {
  final Set<String>? restrictTo;

  const ImmichTagPickRequest({
    required super.op,
    required super.mediaIds,
    this.restrictTo,
  });
}

/// 需要确认 (删除)
class ImmichConfirmRequest extends ImmichOpRequest {
  const ImmichConfirmRequest({required super.op, required super.mediaIds});
}

/// 需要编辑备注
class ImmichMessageRequest extends ImmichOpRequest {
  /// 多项备注一致时取其共同值, 否则为空
  final String initial;

  /// 多项备注原本是否一致 (页面据此选择提示语)
  final bool uniform;

  const ImmichMessageRequest({
    required super.op,
    required super.mediaIds,
    required this.initial,
    required this.uniform,
  });
}

/// 需要选择捆绑主文件
class ImmichLeadPickRequest extends ImmichOpRequest {
  /// 与 [mediaIds] 对应的媒体, 页面用于列出文件名
  final List<MediaAsset> assets;

  const ImmichLeadPickRequest({
    required super.op,
    required super.mediaIds,
    required this.assets,
  });
}

/// 页面回填的用户输入
sealed class ImmichOpAnswer {
  const ImmichOpAnswer();
}

class ImmichTagsAnswer extends ImmichOpAnswer {
  final Set<String> tagIds;

  const ImmichTagsAnswer(this.tagIds);
}

class ImmichMessageAnswer extends ImmichOpAnswer {
  final String text;

  const ImmichMessageAnswer(this.text);
}

class ImmichLeadAnswer extends ImmichOpAnswer {
  final String leadId;

  const ImmichLeadAnswer(this.leadId);
}

/// 确认类操作通过
class ImmichConfirmedAnswer extends ImmichOpAnswer {
  const ImmichConfirmedAnswer();
}

/// 操作结果 (提示文案由页面给出)
sealed class ImmichOpOutcome {
  const ImmichOpOutcome();
}

/// 执行成功; [affected] 为受影响项数
class ImmichOpSuccess extends ImmichOpOutcome {
  final ImmichBatchOp op;
  final int affected;

  const ImmichOpSuccess(this.op, this.affected);
}

/// 执行失败
class ImmichOpFailure extends ImmichOpOutcome {
  final Object error;

  const ImmichOpFailure(this.error);
}

/// 未执行 (校验不通过)
class ImmichOpRejected extends ImmichOpOutcome {
  final ImmichOpRejection reason;

  const ImmichOpRejected(this.reason);
}

/// 单张媒体标签编辑的增删计划
class ImmichTagEdit {
  final List<String> toAdd;
  final List<String> toRemove;

  const ImmichTagEdit({required this.toAdd, required this.toRemove});

  /// 与原有标签一致, 无需写服务端
  bool get isEmpty => toAdd.isEmpty && toRemove.isEmpty;
}

// 流程状态与操作

/// 批量操作流程状态
class ImmichOpsState {
  /// 是否处于多选模式
  final bool selectionMode;

  /// 当前操作 (等待输入或执行中); 空闲为 null
  final ImmichBatchOp? op;

  /// 等待用户补充输入的请求; 无需输入时为 null
  final ImmichOpRequest? request;

  /// 最近一次操作的结果, 由页面读取后拼提示
  final ImmichOpOutcome? outcome;

  const ImmichOpsState({
    this.selectionMode = false,
    this.op,
    this.request,
    this.outcome,
  });
}

/// 批量操作流程
@riverpod
class ImmichOps extends _$ImmichOps {
  @override
  ImmichOpsState build() => const ImmichOpsState();

  // 多选模式

  /// 切换多选模式; 退出时一并清空选中集合
  void toggleSelectionMode() {
    if (state.selectionMode) {
      clearSelection();
    } else {
      state = const ImmichOpsState(selectionMode: true);
    }
  }

  /// 长按媒体: 进入多选模式并切换该项
  void longPressAsset(String mediaId) {
    state = const ImmichOpsState(selectionMode: true);
    ref.read(immichSelectionProvider.notifier).toggle(mediaId);
  }

  /// 清空选中并退出多选模式
  void clearSelection() {
    ref.read(immichSelectionProvider.notifier).clear();
    state = const ImmichOpsState();
  }

  // 批量操作

  /// 开始一次批量操作
  ///
  /// 返回需要用户补充输入的请求; 直接执行完毕或校验不通过时返回 null,
  /// 此时结果已写入 [ImmichOpsState.outcome]。
  Future<ImmichOpRequest?> start(ImmichBatchOp op) async {
    // 每次操作都从干净状态开始, 上一次的请求与结果不跨操作残留
    state = ImmichOpsState(selectionMode: state.selectionMode, op: op);

    final ids = _selectedIdsOrdered();
    if (ids.isEmpty) return null;

    switch (op) {
      case ImmichBatchOp.addTags:
        return ImmichTagPickRequest(op: op, mediaIds: ids);
      case ImmichBatchOp.removeTags:
        final present = _linkedTagIds(ids);
        if (present.isEmpty) {
          _reject(ImmichOpRejection.noTags);
          return null;
        }
        return ImmichTagPickRequest(op: op, mediaIds: ids, restrictTo: present);
      case ImmichBatchOp.delete:
        return ImmichConfirmRequest(op: op, mediaIds: ids);
      case ImmichBatchOp.message:
        final assets = _assetsByIds(ids);
        final first = assets.isEmpty ? null : assets.first.message;
        final uniform =
            assets.every((asset) => (asset.message ?? '') == (first ?? ''));
        return ImmichMessageRequest(
          op: op,
          mediaIds: ids,
          initial: uniform ? (first ?? '') : '',
          uniform: uniform,
        );
      case ImmichBatchOp.bundle:
        final bundleAssets = _assetsByIds(ids);
        if (ids.length < 2 || bundleAssets.length < 2) {
          _reject(ImmichOpRejection.tooFewForBundle);
          return null;
        }
        return ImmichLeadPickRequest(
          op: op,
          mediaIds: ids,
          assets: bundleAssets,
        );
      case ImmichBatchOp.restore:
        await _execute(op, ids);
        return null;
      case ImmichBatchOp.unbundle:
        await _execute(op, ids);
        return null;
    }
  }

  /// 回填用户输入并执行; 空勾选等同于没有改动, 不产生结果
  Future<void> submit(ImmichOpAnswer answer) async {
    final pending = state.request;
    if (pending == null) return;
    final op = pending.op;
    final ids = pending.mediaIds;
    // 输入已收到, 进入执行阶段
    state = ImmichOpsState(selectionMode: state.selectionMode, op: op);

    switch (answer) {
      case ImmichTagsAnswer(:final tagIds):
        if (tagIds.isEmpty) return;
        await _execute(op, ids, tagIds: tagIds);
      case ImmichMessageAnswer(:final text):
        await _execute(op, ids, text: text);
      case ImmichLeadAnswer(:final leadId):
        await _execute(op, ids, leadId: leadId);
      case ImmichConfirmedAnswer():
        await _execute(op, ids);
    }
  }

  /// 用户关闭了弹窗: 本次操作作废, 不产生结果
  void cancel() {
    state = ImmichOpsState(selectionMode: state.selectionMode);
  }

  // 单张媒体的标签编辑

  /// 勾选结果相对现有标签的增删 (无需改动时 [ImmichTagEdit.isEmpty])
  ImmichTagEdit planTagEdit(Iterable<String> currentIds, Set<String> checked) {
    final current = currentIds.toSet();
    return ImmichTagEdit(
      toAdd: checked.difference(current).toList(),
      toRemove: current.difference(checked).toList(),
    );
  }

  /// 执行单张媒体的标签编辑 (先加后删)
  Future<void> applyTagEdit(String mediaId, ImmichTagEdit edit) async {
    final actions = ref.read(immichActionsProvider.notifier);
    if (edit.toAdd.isNotEmpty) await actions.addTags([mediaId], edit.toAdd);
    if (edit.toRemove.isNotEmpty) {
      await actions.removeTags([mediaId], edit.toRemove);
    }
  }

  // 执行

  /// 按操作种类走具体调用序列, 结果写入状态 (成功后退出多选)
  Future<void> _execute(
    ImmichBatchOp op,
    List<String> mediaIds, {
    Set<String> tagIds = const {},
    String text = '',
    String? leadId,
  }) async {
    final actions = ref.read(immichActionsProvider.notifier);
    try {
      var affected = mediaIds.length;
      switch (op) {
        case ImmichBatchOp.addTags:
          await actions.addTags(mediaIds, tagIds.toList());
        case ImmichBatchOp.removeTags:
          await actions.removeTags(mediaIds, tagIds.toList());
        case ImmichBatchOp.delete:
          await actions.setDeleted(mediaIds, true);
        case ImmichBatchOp.restore:
          await actions.setDeleted(mediaIds, false);
        case ImmichBatchOp.message:
          await actions.setMessage(mediaIds, text);
        case ImmichBatchOp.bundle:
          final members = [
            for (final id in mediaIds)
              if (id != leadId) id,
          ];
          await actions.bundle(leadId!, members);
          affected = members.length;
        case ImmichBatchOp.unbundle:
          await actions.unbundle(mediaIds);
      }
      state = ImmichOpsState(outcome: ImmichOpSuccess(op, affected));
    } catch (e) {
      state = ImmichOpsState(
        selectionMode: state.selectionMode,
        outcome: ImmichOpFailure(e),
      );
    }
  }

  /// 选中项 id, 按网格顺序 (首位作为捆绑主文件的默认值)
  List<String> _selectedIdsOrdered() {
    final page = ref.read(immichMediaProvider).valueOrNull;
    final selection = ref.read(immichSelectionProvider);
    if (page == null) return selection.toList();
    return [
      for (final asset in page.assets)
        if (selection.contains(asset.id)) asset.id,
    ];
  }

  /// 选中项在当前列表里已关联的标签并集 (移除标签时限定可选范围)
  Set<String> _linkedTagIds(List<String> ids) {
    final page = ref.read(immichMediaProvider).valueOrNull;
    final present = <String>{};
    for (final id in ids) {
      present.addAll(page?.tagIdsByMedia[id] ?? const <String>[]);
    }
    return present;
  }

  /// 按 id 取回当前列表里的媒体, 顺序与 [ids] 一致 (列表里没有的跳过)
  List<MediaAsset> _assetsByIds(List<String> ids) {
    final byId = {
      for (final asset
          in ref.read(immichMediaProvider).valueOrNull?.assets ??
              const <MediaAsset>[])
        asset.id: asset,
    };
    return [
      for (final id in ids)
        if (byId[id] != null) byId[id]!,
    ];
  }

  /// 记录校验不通过的原因
  void _reject(ImmichOpRejection reason) {
    state = ImmichOpsState(
      selectionMode: state.selectionMode,
      outcome: ImmichOpRejected(reason),
    );
  }
}
