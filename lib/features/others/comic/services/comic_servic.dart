// 从章节名称中提取章节序号
int getChapterIndex(String chapterName){
  // 确保章节名格式为 "数字_章节名"
  final parts = chapterName.split('_');
  if (parts.isNotEmpty) {
    return int.tryParse(parts[0]) ?? 0;
  }
  return 0;
}
// 从章节名称中提取章节名
String getChapterTitle(String chapterName){
  final parts = chapterName.split('_');
  if (parts.length>1) {
    return parts[1];
  }
  return "";
}