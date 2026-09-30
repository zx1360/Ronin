import 'package:hive_flutter/hive_flutter.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:torrid/core/utils/util.dart';

part 'chapter_info.g.dart';

// 章节元数据
@HiveType(typeId: 32)
@JsonSerializable(fieldRename: FieldRename.snake)
class ChapterInfo {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String comicId;
  @HiveField(2)
  final int chapterIndex;
  @HiveField(3)
  final String dirName;
  @HiveField(4)
  @JsonKey(defaultValue: [])
  // {
  //   'path': file.path,
  //   'width': size.width,
  //   'height': size.height,
  // }
  final List<Map<String, dynamic>> images;
  @HiveField(5)
  final int imageCount;

  ChapterInfo({
    required this.id,
    required this.comicId,
    required this.chapterIndex,
    required this.dirName,
    required this.images,
    int? imageCount,
  }): imageCount = imageCount??images.length;
  ChapterInfo.newOne({
    required this.comicId,
    required this.chapterIndex,
    required this.dirName,
    required this.images,
    int? imageCount,
  }):id=generateId(), imageCount=imageCount??images.length;

  ChapterInfo copyWith({
    String? id,
    String? comicId,
    int? chapterIndex,
    String? dirName,
    List<Map<String, dynamic>>? images,
    int? imageCount,
  }) {
    return ChapterInfo(
      id: id ?? this.id,
      comicId: comicId ?? this.comicId,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      dirName: dirName ?? this.dirName,
      // 必须显式重建为 Map<String, dynamic>：直接 cast 的话列表元素仍是原始 Map，
      // 后续按 Map<String, dynamic> 使用时会抛类型错误
      images: images?.map((e) => Map<String, dynamic>.from(e)).toList() ?? this.images,
      imageCount: imageCount ?? images?.length ?? this.imageCount,
    );
  }

  /// 序列化
  factory ChapterInfo.fromJson(Map<String, dynamic> json) => _$ChapterInfoFromJson(json);
  Map<String, dynamic> toJson() => _$ChapterInfoToJson(this);
}
