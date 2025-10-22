import 'package:hive_flutter/hive_flutter.dart';

part 'comic_progress.g.dart';


// TODO: 更改下不必占用HiveType, 利用List<Map>或Map存储轻量元数据.
@HiveType(typeId: 30)
class ComicProgress {
  @HiveField(0)
  final String name;

  @HiveField(1)
  final int chapterIndex;

  @HiveField(2)
  final int pageIndex;

  ComicProgress({
    required this.name,
    required this.chapterIndex,
    required this.pageIndex,
  });
}
