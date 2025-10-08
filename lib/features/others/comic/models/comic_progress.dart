import 'package:hive_flutter/hive_flutter.dart';

part 'comic_progress.g.dart';

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
