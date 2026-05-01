/// 媒体-标签关联模型 - 对应服务端 media_tag_links 表
library;

import 'package:json_annotation/json_annotation.dart';

part 'media_tag_link.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class MediaTagLink {
  final String mediaId;
  final String tagId;

  const MediaTagLink({
    required this.mediaId,
    required this.tagId,
  });

  factory MediaTagLink.fromJson(Map<String, dynamic> json) =>
      _$MediaTagLinkFromJson(json);

  Map<String, dynamic> toJson() => _$MediaTagLinkToJson(this);

  /// 转换为数据库 Map
  Map<String, dynamic> toDbMap() => {
        'media_id': mediaId,
        'tag_id': tagId,
      };

  factory MediaTagLink.fromDbMap(Map<String, dynamic> map) => MediaTagLink(
        mediaId: map['media_id'] as String,
        tagId: map['tag_id'] as String,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaTagLink &&
          runtimeType == other.runtimeType &&
          mediaId == other.mediaId &&
          tagId == other.tagId;

  @override
  int get hashCode => mediaId.hashCode ^ tagId.hashCode;
}
