// 漫画信息模型
class ComicInfo {
  final String name;
  final String path;
  final String? coverImage;
  final int chapterCount;
  final int totalImages;

  ComicInfo({
    required this.name,
    required this.path,
    this.coverImage,
    required this.chapterCount,
    required this.totalImages,
  });
}

// 章节信息模型
class ChapterInfo {
  // 章节标题
  final String title;
  // 章节文件夹名
  final String name;
  // 章节路径
  final String path;
  final int imageCount;
  final int chapterNumber;

  ChapterInfo({
    this.title = "",
    required this.name,
    required this.path,
    required this.imageCount,
    required this.chapterNumber,
  });
}