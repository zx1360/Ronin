import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/core/api/generated/api_contract.dart' show ApiPath;
import 'package:torrid/core/services/debug/logging_service.dart';
import 'package:torrid/core/services/storage/public_storage_service.dart';
import 'package:torrid/features/others/gallery/models/media_asset.dart';
import 'package:torrid/features/others/gallery/models/media_patch_intent.dart';
import 'package:torrid/features/others/gallery/providers/media_providers.dart';
import 'package:torrid/features/others/gallery/providers/service_providers.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';

part 'media_detail_providers.g.dart';

/// 媒体详情页状态
class MediaDetailState {
  const MediaDetailState({
    this.asset,
    this.groupMembers = const [],
    this.groupIndex = 0,
    this.saving = false,
    this.downloading = false,
  });

  /// 页面主体文件 (未捆绑文件即其本身)
  final MediaAsset? asset;

  /// 组成员 (含主文件, 首位为主文件)
  final List<MediaAsset> groupMembers;

  /// 当前查看的组成员下标
  final int groupIndex;

  final bool saving;
  final bool downloading;

  bool get hasGroup => groupMembers.length > 1;

  /// 当前查看的文件
  MediaAsset? get current {
    if (groupMembers.isEmpty) return asset;
    if (groupIndex < 0 || groupIndex >= groupMembers.length) return asset;
    return groupMembers[groupIndex];
  }

  MediaDetailState copyWith({
    MediaAsset? asset,
    List<MediaAsset>? groupMembers,
    int? groupIndex,
    bool? saving,
    bool? downloading,
  }) {
    return MediaDetailState(
      asset: asset ?? this.asset,
      groupMembers: groupMembers ?? this.groupMembers,
      groupIndex: groupIndex ?? this.groupIndex,
      saving: saving ?? this.saving,
      downloading: downloading ?? this.downloading,
    );
  }
}

/// 媒体详情页的组成员 / 备注 / 下载
@riverpod
class MediaDetail extends _$MediaDetail {
  bool _disposed = false;

  @override
  MediaDetailState build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    return const MediaDetailState();
  }

  /// 载入主体文件及其捆绑组成员 (页面进入时调用)
  Future<void> load(MediaAsset asset) async {
    state = MediaDetailState(asset: asset, groupMembers: [asset]);
    final db = ref.read(galleryDatabaseProvider);
    final members = await db.getGroupMembers(asset.id);
    // 页面已销毁或载入期间切换了文件时丢弃结果
    if (_disposed || state.asset?.id != asset.id) return;
    state = state.copyWith(groupMembers: [asset, ...members]);
  }

  /// 切换当前查看的组成员
  void selectIndex(int index) {
    if (index < 0 || index >= state.groupMembers.length) return;
    state = state.copyWith(groupIndex: index);
  }

  /// 保存当前查看文件的备注 (本地立即生效, 服务端经写缓冲推送)
  ///
  /// 备注逐文件独立, 空串表示清空。
  Future<void> saveMessage(String rawMessage) async {
    final target = state.current;
    if (target == null) return;

    final message = rawMessage.trim();
    state = state.copyWith(saving: true);
    try {
      final updated = target.copyWith(
        message: message.isEmpty ? null : message,
        clearMessage: message.isEmpty,
      );
      await ref.read(mediaAssetListProvider.notifier).applyPatch(
            original: target,
            updated: updated,
            intent: MediaPatchIntent(message: message),
          );
      _replaceMember(updated);
    } finally {
      if (!_disposed) state = state.copyWith(saving: false);
    }
  }

  /// 将当前查看文件移出捆绑组
  Future<void> removeCurrentFromGroup() async {
    final member = state.current;
    if (member == null || member.groupId == null) return;

    await ref.read(mediaAssetListProvider.notifier).unbundleMedia([member.id]);
    if (_disposed) return;

    final members = List<MediaAsset>.from(state.groupMembers)
      ..removeAt(state.groupIndex);
    var index = state.groupIndex;
    if (index >= members.length) index = members.length - 1;
    if (index < 0) index = 0;
    state = state.copyWith(groupMembers: members, groupIndex: index);
  }

  /// 下载当前查看文件到公共相册目录, 返回保存后的路径
  Future<String> downloadToPublic() async {
    final target = state.current;
    if (target == null) throw Exception('没有可下载的文件');

    state = state.copyWith(downloading: true);
    try {
      final apiClient = ref.read(apiClientManagerProvider);
      final response =
          await apiClient.getBinary(ApiPath.galleryIdTypePath(target.id, 'file'));
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        throw Exception('下载的文件数据为空');
      }

      final file = await PublicStorageService.saveBytes(
        subDir: PublicStorageService.dirGallery,
        fileName: _fileName(target.filePath),
        bytes: bytes,
      );
      if (file == null) {
        throw Exception('保存到公共目录失败，请检查存储权限');
      }
      AppLogger().info('文件已保存: ${file.path}');
      return file.path;
    } finally {
      if (!_disposed) state = state.copyWith(downloading: false);
    }
  }

  /// 备注写回后同步内存中的组成员, 避免详情页显示旧值
  void _replaceMember(MediaAsset asset) {
    final index = state.groupMembers.indexWhere((m) => m.id == asset.id);
    if (index < 0) return;
    final members = List<MediaAsset>.from(state.groupMembers)..[index] = asset;
    state = state.copyWith(
      asset: state.asset?.id == asset.id ? asset : null,
      groupMembers: members,
    );
  }

  String _fileName(String path) => path.split('/').last.split('\\').last;
}
