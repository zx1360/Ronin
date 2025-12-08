import 'package:pinyin/pinyin.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/others/comic/models/chapter_info.dart';
import 'package:torrid/features/others/comic/models/comic_info.dart';
import 'package:torrid/features/others/comic/models/comic_preference.dart';
import 'package:torrid/features/others/comic/provider/box_provider.dart';

part 'status_provider.g.dart';

// ----源数据----
// 不采取转同步, 方便和在线阅读获取同步.
// // comicInfo  对于含有中文的, 按拼音升序.
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

// // chapterInfo
// @riverpod
// List<ChapterInfo> chapterInfos(ChapterInfosRef ref) {
//   final asyncVal = ref.watch(chapterInfoStreamProvider);
//   if (asyncVal.hasError) {
//     throw asyncVal.error!;
//   }
//   return asyncVal.asData?.value ?? [];
// }

// ----带有业务逻辑的数据源----
// 获取某个漫画的偏好信息
@riverpod
ComicPreference comicPrefWithComicId(
  ComicPrefWithComicIdRef ref, {
  required String comicId,
}) {
  return ref.read(comicPrefBoxProvider).get(comicId) ??
      ComicPreference(comicId: comicId, chapterIndex: 0, pageIndex: 0);
}

// 获取某个漫画的所有章节信息.
@riverpod
Future<List<ChapterInfo>> chaptersWithComicId(
  ChaptersWithComicIdRef ref, {
  required String comicId,
}) async {
  final List<ChapterInfo> chapters = await ref.watch(chapterInfoStreamProvider.future);
  return chapters.where((chapter) => chapter.comicId == comicId).toList()
    ..sort((a, b) => a.chapterIndex.compareTo(b.chapterIndex));
}
