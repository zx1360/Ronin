/// 批量获取响应模型 - 对应 GET /api/gallery/batch 的响应
library;

import 'package:json_annotation/json_annotation.dart';
import 'package:torrid/features/others/gallery/models/media_asset.dart';
import 'package:torrid/features/others/gallery/models/tag.dart';
import 'package:torrid/features/others/gallery/models/media_tag_link.dart';

part 'batch_data.g.dart';

// 数据接收和发送共用的批次响应模型
@JsonSerializable()
class BatchData {
  /// 媒体文件列表
  @JsonKey(name: 'media_assets', defaultValue: [])
  final List<MediaAsset> medias;

  /// 标签列表 (可能为 null)
  @JsonKey(name: 'tags', defaultValue: [])
  final List<Tag> tags;

  /// 媒体-标签关联列表 (可能为 null)
  @JsonKey(name: 'media_tag_links', defaultValue: [])
  final List<MediaTagLink> links;

  const BatchData({
    required this.medias,
    required this.tags,
    required this.links,
  });

  factory BatchData.fromJson(Map<String, dynamic> json) =>
      _$BatchDataFromJson(json);

  // 深度使用toJson以确保嵌套对象也被正确序列化
  Map<String, dynamic> toJson() => {
        'media_assets': medias.map((media) => media.toJson()).toList(),
        'tags': tags.map((tag) => tag.toJson()).toList(),
        'media_tag_links': links.map((link) => link.toJson()).toList(),
      };
  // Map<String, dynamic> toJson() => _$BatchDataToJson(this);
}
