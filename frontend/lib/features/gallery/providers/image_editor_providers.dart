import 'dart:ui' show Size;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/gallery/models/media_asset.dart';
import 'package:torrid/features/gallery/models/media_edit_params.dart';
import 'package:torrid/features/gallery/models/media_patch_intent.dart';
import 'package:torrid/features/gallery/providers/media_providers.dart';

part 'image_editor_providers.g.dart';

/// 裁切手柄与拖动区域
enum ImageCropHandle {
  none,
  topLeft,
  top,
  topRight,
  right,
  bottomRight,
  bottom,
  bottomLeft,
  left,
  move,
}

/// 图片编辑状态 (裁切坐标为原图像素)
class ImageEditState {
  const ImageEditState({
    this.asset,
    this.rotation = 0,
    this.cropLeft = 0,
    this.cropTop = 0,
    this.cropRight = 0,
    this.cropBottom = 0,
    this.cropInitialized = false,
    this.imageSize,
    this.saving = false,
  });

  /// 被编辑的媒体文件
  final MediaAsset? asset;

  /// 旋转角度 (0/90/180/270)
  final int rotation;

  /// 裁切区域 (原图像素坐标)
  final double cropLeft;
  final double cropTop;
  final double cropRight;
  final double cropBottom;

  /// 裁切区域是否已确定 (未确定时待原图尺寸已知后置为全图)
  final bool cropInitialized;

  /// 原图像素尺寸
  final Size? imageSize;

  final bool saving;

  /// 原图尺寸已知
  bool get hasImageSize => imageSize != null;

  /// 是否裁切过 (裁切区小于全图)
  bool get hasCrop =>
      imageSize != null &&
      !(cropLeft <= 0 &&
          cropTop <= 0 &&
          cropRight >= imageSize!.width &&
          cropBottom >= imageSize!.height);

  ImageEditState copyWith({
    MediaAsset? asset,
    int? rotation,
    double? cropLeft,
    double? cropTop,
    double? cropRight,
    double? cropBottom,
    bool? cropInitialized,
    Size? imageSize,
    bool? saving,
  }) {
    return ImageEditState(
      asset: asset ?? this.asset,
      rotation: rotation ?? this.rotation,
      cropLeft: cropLeft ?? this.cropLeft,
      cropTop: cropTop ?? this.cropTop,
      cropRight: cropRight ?? this.cropRight,
      cropBottom: cropBottom ?? this.cropBottom,
      cropInitialized: cropInitialized ?? this.cropInitialized,
      imageSize: imageSize ?? this.imageSize,
      saving: saving ?? this.saving,
    );
  }
}

/// 图片编辑: 旋转 / 裁切 / 保存
///
/// 页面只保留手势与布局, 编辑数值与写路径都在这里。
@riverpod
class ImageEdit extends _$ImageEdit {
  @override
  ImageEditState build() => const ImageEditState();

  /// 载入媒体及其已有编辑参数 (页面进入时调用)
  void load(MediaAsset asset) {
    final params = ImageEditParams.tryParse(asset.editParams);
    state = ImageEditState(
      asset: asset,
      rotation: params?.rotation ?? 0,
      cropLeft: params?.cropLeft ?? 0,
      cropTop: params?.cropTop ?? 0,
      cropRight: params?.cropRight ?? 0,
      cropBottom: params?.cropBottom ?? 0,
      cropInitialized:
          (params?.cropRight ?? 0) > 0 || (params?.cropBottom ?? 0) > 0,
    );
  }

  /// 旋转 90°; 旋转后裁切重置为全图
  void rotate() {
    state = _fullCrop(state.copyWith(rotation: (state.rotation + 90) % 360));
  }

  /// 原图尺寸已知 (由图片流回调), 尚未裁切时置为全图
  void setImageSize(Size size) {
    if (state.imageSize == size) return;
    state = state.cropInitialized
        ? state.copyWith(imageSize: size)
        : _fullCrop(state.copyWith(imageSize: size));
  }

  /// 裁切重置为全图
  void resetCropToFull() {
    if (state.imageSize == null) return;
    state = _fullCrop(state);
  }

  /// 拖动手柄, [dx]/[dy] 为原图像素位移
  void drag(ImageCropHandle handle, double dx, double dy) {
    final size = state.imageSize;
    if (size == null) return;

    final iw = size.width;
    final ih = size.height;
    var cl = state.cropLeft;
    var ct = state.cropTop;
    var cr = state.cropRight;
    var cb = state.cropBottom;

    switch (handle) {
      case ImageCropHandle.topLeft:
        cl += dx;
        ct += dy;
      case ImageCropHandle.top:
        ct += dy;
      case ImageCropHandle.topRight:
        cr += dx;
        ct += dy;
      case ImageCropHandle.right:
        cr += dx;
      case ImageCropHandle.bottomRight:
        cr += dx;
        cb += dy;
      case ImageCropHandle.bottom:
        cb += dy;
      case ImageCropHandle.bottomLeft:
        cl += dx;
        cb += dy;
      case ImageCropHandle.left:
        cl += dx;
      case ImageCropHandle.move:
        final mw = cr - cl;
        final mh = cb - ct;
        if (cl + dx >= 0 && cr + dx <= iw) {
          cl += dx;
          cr = cl + mw;
        }
        if (ct + dy >= 0 && cb + dy <= ih) {
          ct += dy;
          cb = ct + mh;
        }
      case ImageCropHandle.none:
        return;
    }

    cl = cl.clamp(0.0, cr - 50);
    ct = ct.clamp(0.0, cb - 50);
    cr = cr.clamp(cl + 50, iw);
    cb = cb.clamp(ct + 50, ih);
    state = state.copyWith(
      cropLeft: cl,
      cropTop: ct,
      cropRight: cr,
      cropBottom: cb,
    );
  }

  /// 保存编辑参数 (本地立即生效, 服务端经写缓冲推送)
  Future<void> save() async {
    final asset = state.asset;
    if (asset == null || state.saving) return;

    state = state.copyWith(saving: true);
    try {
      final params = ImageEditParams(
        rotation: state.rotation,
        cropLeft: state.cropLeft,
        cropTop: state.cropTop,
        cropRight: state.cropRight,
        cropBottom: state.cropBottom,
      ).toJson(includeCrop: state.hasCrop);
      await ref.read(mediaAssetListProvider.notifier).applyPatch(
            mediaId: asset.id,
            intent: MediaPatchIntent(editParams: params),
          );
    } finally {
      state = state.copyWith(saving: false);
    }
  }

  /// 清除所有编辑参数, 还原为原始文件
  Future<void> revert() async {
    final asset = state.asset;
    if (asset == null) return;
    await ref.read(mediaAssetListProvider.notifier).applyPatch(
          mediaId: asset.id,
          intent: const MediaPatchIntent(clearEditParams: true),
        );
  }

  /// 裁切区置为全图
  ImageEditState _fullCrop(ImageEditState s) {
    final size = s.imageSize;
    if (size == null) return s;
    return s.copyWith(
      cropLeft: 0,
      cropTop: 0,
      cropRight: size.width,
      cropBottom: size.height,
      cropInitialized: true,
    );
  }
}
