import 'package:json_annotation/json_annotation.dart';
import 'package:torrid/core/utils/util.dart';

part 'comic_info.g.dart';

// 漫画元数据

@JsonSerializable(fieldRename: FieldRename.snake)
class ComicInfo {
  final String id;

  @JsonKey(name: "title")
  final String comicName;

  final String coverImage;

  final int chapterCount;

  final int imageCount;

  final bool? isPublic;

  final bool? readed;

  ComicInfo({
    required this.id,
    required this.comicName,
    required this.coverImage,
    required this.chapterCount,
    required this.imageCount,
    this.isPublic = true,
    this.readed = false,
  });

  ComicInfo.newOne({
    required this.comicName,
    required this.coverImage,
    required this.chapterCount,
    required this.imageCount,
  }) : id = generateId(),
       isPublic = true,
       readed = false;

  ComicInfo copyWith({
    String? id,
    String? comicName,
    String? coverImage,
    int? chapterCount,
    int? imageCount,
    bool? isPublic,
    bool? readed,
  }) {
    return ComicInfo(
      id: id ?? this.id,
      comicName: comicName ?? this.comicName,
      coverImage: coverImage ?? this.coverImage,
      chapterCount: chapterCount ?? this.chapterCount,
      imageCount: imageCount ?? this.imageCount,
      isPublic: isPublic ?? this.isPublic,
      readed: readed ?? this.readed,
    );
  }

  // 序列化
  factory ComicInfo.fromJson(Map<String, dynamic> json) =>
      _$ComicInfoFromJson(json);
  Map<String, dynamic> toJson() => _$ComicInfoToJson(this);
}
