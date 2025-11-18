import 'package:hive_flutter/hive_flutter.dart';
import 'package:json_annotation/json_annotation.dart';

part 'comic_preference.g.dart';

// TODO: 删掉pageIndex字段, 在加入进度条Provider时候做吧.
@HiveType(typeId: 30)
@JsonSerializable()
class ComicPreference {
  @HiveField(0)
  final String comicId;

  @HiveField(1)
  final int chapterIndex;

  @HiveField(2)
  final int pageIndex;

  @HiveField(3)
  final bool flipReading;

  ComicPreference({
    required this.comicId,
    required this.chapterIndex,
    required this.pageIndex,
    this.flipReading = true,
  });

  ComicPreference copyWith({
    String? comicId,
    int? chapterIndex,
    int? pageIndex,
    bool? flipReading,
  }) {
    return ComicPreference(
      comicId: comicId ?? this.comicId,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      pageIndex: pageIndex ?? this.pageIndex,
      flipReading: flipReading ?? this.flipReading,
    );
  }
}
