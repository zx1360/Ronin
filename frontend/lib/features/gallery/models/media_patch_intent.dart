/// 媒体标注更新意图
///
/// 只记录"本次要修改的字段", 未设置的字段不会出现在请求体里（服务端保持原值）。
/// 语义约定:
/// - [message] 空串表示清空备注
/// - [groupId] 表示捆绑到该主文件, [clearGroup] 表示解绑（互斥, 后者优先判定）
/// - [editParams] 为 JSON 文本, [clearEditParams] 表示清除
class MediaPatchIntent {
  final bool? isDeleted;
  final String? message;
  final String? groupId;
  final bool clearGroup;
  final String? editParams;
  final bool clearEditParams;
  final bool markProcessed;

  const MediaPatchIntent({
    this.isDeleted,
    this.message,
    this.groupId,
    this.clearGroup = false,
    this.editParams,
    this.clearEditParams = false,
    this.markProcessed = false,
  });

  bool get isEmpty =>
      isDeleted == null &&
      message == null &&
      groupId == null &&
      !clearGroup &&
      editParams == null &&
      !clearEditParams &&
      !markProcessed;

  /// 合并（[other] 中显式给出的字段覆盖本对象）
  MediaPatchIntent merge(MediaPatchIntent other) {
    var nextGroupId = groupId;
    var nextClearGroup = clearGroup;
    if (other.groupId != null) {
      nextGroupId = other.groupId;
      nextClearGroup = false;
    } else if (other.clearGroup) {
      nextGroupId = null;
      nextClearGroup = true;
    }

    var nextEditParams = editParams;
    var nextClearEdit = clearEditParams;
    if (other.editParams != null) {
      nextEditParams = other.editParams;
      nextClearEdit = false;
    } else if (other.clearEditParams) {
      nextEditParams = null;
      nextClearEdit = true;
    }

    return MediaPatchIntent(
      isDeleted: other.isDeleted ?? isDeleted,
      message: other.message ?? message,
      groupId: nextGroupId,
      clearGroup: nextClearGroup,
      editParams: nextEditParams,
      clearEditParams: nextClearEdit,
      markProcessed: markProcessed || other.markProcessed,
    );
  }

  /// 构造 PATCH /API/gallery/media 请求体
  Map<String, dynamic> toBody(List<String> mediaIds) {
    final body = <String, dynamic>{'media_ids': mediaIds};
    if (isDeleted != null) body['is_deleted'] = isDeleted;
    if (message != null) body['message'] = message;
    if (groupId != null) {
      body['group_id'] = groupId;
    } else if (clearGroup) {
      body['group_id'] = null;
    }
    if (editParams != null) {
      body['edit_params'] = editParams;
    } else if (clearEditParams) {
      body['edit_params'] = null;
    }
    if (markProcessed) body['mark_processed'] = true;
    return body;
  }
}
