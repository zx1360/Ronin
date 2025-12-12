import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:torrid/core/utils/util.dart';

part 'comic_info.g.dart';

// 漫画元数据
@HiveType(typeId: 31)
@JsonSerializable(fieldRename: FieldRename.snake)
class ComicInfo {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String comicName;
  @HiveField(2)
  final String coverImage;
  @HiveField(3)
  final int chapterCount;
  @HiveField(4)
  final int imageCount;

  ComicInfo({
    required this.id,
    required this.comicName,
    required this.coverImage,
    required this.chapterCount,
    required this.imageCount,
  });

  ComicInfo.newOne({
    required this.comicName,
    required this.coverImage,
    required this.chapterCount,
    required this.imageCount,
  }) : id = generateId();

  ComicInfo copyWith({
    String? id,
    String? comicName,
    String? coverImage,
    int? chapterCount,
    int? imageCount,
  }) {
    return ComicInfo(
      id: id ?? this.id,
      comicName: comicName ?? this.comicName,
      coverImage: coverImage ?? this.coverImage,
      chapterCount: chapterCount ?? this.chapterCount,
      imageCount: imageCount ?? this.imageCount,
    );
  }

  // 序列化
  factory ComicInfo.fromJson(Map<String, dynamic> json) => _$ComicInfoFromJson(json);
  Map<String, dynamic> toJson() => _$ComicInfoToJson(this);
}
