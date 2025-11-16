import 'package:hive_flutter/hive_flutter.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:torrid/shared/utils/util.dart';

part 'chapter_info.g.dart';

// 章节元数据
@HiveType(typeId: 32)
@JsonSerializable()
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
}
