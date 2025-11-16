import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/others/comic/models/chapter_info.dart';
import 'package:torrid/features/others/comic/models/comic_info.dart';
import 'package:torrid/features/others/comic/models/comic_preference.dart';
import 'package:torrid/features/others/comic/provider/box_provider.dart';

part 'status_provider.g.dart';

// ----源数据----
// comicPref
@riverpod
List<ComicPreference> comicPrefs(ComicPrefsRef ref) {
  final asyncVal = ref.watch(comicPrefStreamProvider);
  if (asyncVal.hasError) {
    throw asyncVal.error!;
  }
  return asyncVal.asData?.value ?? [];
}

// comicInfo
@riverpod
List<ComicInfo> comicInfos(ComicInfosRef ref) {
  final asyncVal = ref.watch(comicInfoStreamProvider);
  if (asyncVal.hasError) {
    throw asyncVal.error!;
  }
  return asyncVal.asData?.value ?? [];
}

// chapterInfo
@riverpod
List<ChapterInfo> chapterInfos(ChapterInfosRef ref) {
  final asyncVal = ref.watch(chapterInfoStreamProvider);
  if (asyncVal.hasError) {
    throw asyncVal.error!;
  }
  return asyncVal.asData?.value ?? [];
}

// ----带有业务逻辑的数据源----
// 获取某个漫画的偏好信息
@riverpod
ComicPreference? comicPrefWithComicId(
  ComicPrefWithComicIdRef ref, {
  required String comicId,
}) {
  final comicPrefs = ref.read(comicPrefsProvider);
  final targetComicPrefs = comicPrefs.where(
    (comicPref) => comicPref.comicId == comicId,
  );
  return targetComicPrefs.isEmpty ? null : targetComicPrefs.first;
}

// 获取某个漫画的所有章节信息.
@riverpod
List<ChapterInfo> chaptersWithComicId(
  ChaptersWithComicIdRef ref, {
  required String comicId,
}) {
  final List<ChapterInfo> chapters = ref.watch(chapterInfosProvider);
  return chapters.where((chapter) => chapter.comicId == comicId).toList()
    ..sort((a, b) => a.chapterIndex.compareTo(b.chapterIndex));
}
