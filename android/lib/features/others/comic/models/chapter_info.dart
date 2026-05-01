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
      // 可恶这一行害得我改了不下三个小时左右
      // 原版本: 创建一个每个列表元素都转为Map, 且转为Map<String, dynamic>, 但元素本身仍是Map. 什么吊语言特性.
      // images: images?.map((e) => Map.from(e)).toList().cast<Map<String, dynamic>>() ?? this.images,
      images: images?.map((e) => Map<String, dynamic>.from(e)).toList() ?? this.images,
      imageCount: imageCount ?? images?.length ?? this.imageCount,
    );
  }

  /// 序列化
  factory ChapterInfo.fromJson(Map<String, dynamic> json) => _$ChapterInfoFromJson(json);
  Map<String, dynamic> toJson() => _$ChapterInfoToJson(this);
}
