/// Comic 模块的派生状态提供者
///
/// 基于 Box 数据流提供经过处理的同步数据访问。
library;

import 'package:pinyin/pinyin.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/others/comic/models/chapter_info.dart';
import 'package:torrid/features/others/comic/models/comic_info.dart';
import 'package:torrid/features/others/comic/models/comic_preference.dart';
import 'package:torrid/features/others/comic/provider/box_provider.dart';

part 'status_provider.g.dart';

// ============================================================================
// 漫画列表
// ============================================================================

/// 所有本地漫画信息（按拼音升序排列）
/// 
/// 对于含有中文的漫画名，按拼音首字母排序。
@riverpod
List<ComicInfo> comicInfos(ComicInfosRef ref) {
  final asyncVal = ref.watch(comicInfoStreamProvider);
  if (asyncVal.hasError) {
    throw asyncVal.error!;
  }
  final data = asyncVal.asData?.value ?? [];
  return data..sort((a, b) {
    final pinyinA = PinyinHelper.getPinyin(a.comicName).toLowerCase();
    final pinyinB = PinyinHelper.getPinyin(b.comicName).toLowerCase();
    return pinyinA.compareTo(pinyinB);
  });
}

// ============================================================================
// 业务数据查询
// ============================================================================

/// 获取指定漫画的阅读偏好
/// 
/// 如果不存在则返回默认偏好（从第0章开始）。
@riverpod
ComicPreference comicPrefWithComicId(
  ComicPrefWithComicIdRef ref, {
  required String comicId,
}) {
  return ref.read(comicPrefBoxProvider).get(comicId) ??
      ComicPreference(comicId: comicId, chapterIndex: 0);
}

/// 获取指定漫画的所有章节信息
/// 
/// 按章节索引升序排列。
@riverpod
Future<List<ChapterInfo>> chaptersWithComicId(
  ChaptersWithComicIdRef ref, {
  required String comicId,
}) async {
  final chapters = await ref.watch(chapterInfoStreamProvider.future);
  return chapters
      .where((chapter) => chapter.comicId == comicId)
      .toList()
    ..sort((a, b) => a.chapterIndex.compareTo(b.chapterIndex));
}
