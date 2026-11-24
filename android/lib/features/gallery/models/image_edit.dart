import 'dart:convert';
import 'dart:ui';

/// 裁切区域使用未旋转原图的像素坐标，rotation 为逆时针角度。
class ImageEdit {
  final int rotation;
  final Rect? crop;

  const ImageEdit({this.rotation = 0, this.crop});

  factory ImageEdit.parse(String? value) {
    try {
      final json = jsonDecode(value!) as Map<String, dynamic>;
      if (json['type'] != 'image') return const ImageEdit();
      final rotation = ((json['rotation'] as num?)?.toInt() ?? 0) % 360;
      final edges = [
        'crop_left',
        'crop_top',
        'crop_right',
        'crop_bottom',
      ].map((key) => (json[key] as num?)?.toDouble()).toList();
      return ImageEdit(
        rotation: rotation % 90 == 0 ? rotation : 0,
        crop: edges.every((v) => v != null && v.isFinite)
            ? Rect.fromLTRB(edges[0]!, edges[1]!, edges[2]!, edges[3]!)
            : null,
      );
    } catch (_) {
      return const ImageEdit();
    }
  }

  int get quarterTurns => (4 - rotation ~/ 90) % 4;

  Rect cropFor(Size size) {
    final full = Offset.zero & size;
    if (crop == null) return full;
    final clipped = crop!.intersect(full);
    return clipped.width >= 1 && clipped.height >= 1 ? clipped : full;
  }

  String? encode(Size size) {
    final rect = cropFor(size);
    final cropped = rect != (Offset.zero & size);
    if (rotation == 0 && !cropped) return null;
    return jsonEncode({
      'type': 'image',
      'rotation': rotation,
      if (cropped) ...{
        'crop_left': rect.left.round(),
        'crop_top': rect.top.round(),
        'crop_right': rect.right.round(),
        'crop_bottom': rect.bottom.round(),
      },
    });
  }
}
