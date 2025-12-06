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
  final List<Map<String, dynamic>> images;

  ChapterInfo({
    required this.id,
    required this.comicId,
    required this.chapterIndex,
    required this.dirName,
    required this.images,
  });
  ChapterInfo.newOne({
    required this.comicId,
    required this.chapterIndex,
    required this.dirName,
    required this.images,
  }):id=generateId();

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
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'comic_id': comicId,
      'chapter_index': chapterIndex,
      'dir_name': dirName,
      'images': images,
    };
  }
}
