import 'package:hive_flutter/hive_flutter.dart';
import 'package:torrid/shared/utils/util.dart';

part 'chapter_info.g.dart';

// 章节元数据
@HiveType(typeId: 32)
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
  // {
  //   'path': file.path,
  //   'width': size.width,
  //   'height': size.height,
  // }
  late final List<Map<String, dynamic>> images;
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

  /// 序列化
  factory ChapterInfo.fromJson(Map<String, dynamic> json) {
    // 安全转换 images 列表（处理空值和类型异常）
    final List<dynamic> imagesJson = json['images'] ?? [];
    final List<Map<String, dynamic>> images = imagesJson
        .cast<Map<String, dynamic>>()
        .toList();

    return ChapterInfo(
      id: json['id'] as String,
      comicId: json['comic_id'] as String,
      chapterIndex: json['chapter_index'] as int,
      dirName: json['dir_name'] as String,
      images: images,
      imageCount: json['image_count']
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'comic_id': comicId,
      'chapter_index': chapterIndex,
      'dir_name': dirName,
      'images': images,
      'image_count': imageCount
    };
  }
}
