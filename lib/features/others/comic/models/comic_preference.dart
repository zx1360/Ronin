import 'package:hive_flutter/hive_flutter.dart';

part 'comic_preference.g.dart';

@HiveType(typeId: 30)
class ComicPreference {
  @HiveField(0)
  final String comicId;

  @HiveField(1)
  final int chapterIndex;

  /// 已弃用：保留此字段仅为兼容旧数据，新代码不应使用
  /// 注意：@HiveField(2) 编号不可重用
  @Deprecated('保留仅为兼容旧数据')
  @HiveField(2)
  final int pageIndex;

  @HiveField(3)
  final bool flipReading;

  ComicPreference({
    required this.comicId,
    required this.chapterIndex,
    @Deprecated('保留仅为兼容旧数据') this.pageIndex = 0, // 改为可选，默认值为0
    this.flipReading = true,
  });

  ComicPreference copyWith({
    String? comicId,
    int? chapterIndex,
    @Deprecated('保留仅为兼容旧数据') int? pageIndex,
    bool? flipReading,
  }) {
    return ComicPreference(
      comicId: comicId ?? this.comicId,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      // ignore: deprecated_member_use_from_same_package
      pageIndex: pageIndex ?? this.pageIndex,
      flipReading: flipReading ?? this.flipReading,
    );
  }
}
