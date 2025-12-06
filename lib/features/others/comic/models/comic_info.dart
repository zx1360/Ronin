import 'package:hive/hive.dart';
import 'package:torrid/shared/utils/util.dart';

part 'comic_info.g.dart';

// 漫画元数据
@HiveType(typeId: 31)
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

  // 序列化
  factory ComicInfo.fromJson(Map<String, dynamic> json) {
    return ComicInfo(
      id: json['id'] as String,
      comicName: json['title'] as String,
      coverImage: json['cover_image'] as String,
      chapterCount: json['chapter_count'] as int,
      imageCount: json['image_count'] as int,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': comicName,
      'cover_image': coverImage,
      'chapter_count': chapterCount,
      'image_count': imageCount,
    };
  }
}
