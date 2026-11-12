import 'package:pinyin/pinyin.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/others/comic/models/chapter_info.dart';
import 'package:torrid/features/others/comic/models/comic_info.dart';
import 'package:torrid/features/others/comic/models/comic_preference.dart';
import 'package:torrid/features/others/comic/services/comic_store.dart';

part 'status_provider.g.dart';

@riverpod
Stream<List<ComicInfo>> localComics(Ref ref) => ref
    .watch(comicStoreProvider)
    .watchComics()
    .map(
      (items) => items
        ..sort(
          (a, b) => PinyinHelper.getPinyin(a.comicName).toLowerCase().compareTo(
            PinyinHelper.getPinyin(b.comicName).toLowerCase(),
          ),
        ),
    );

@riverpod
List<ComicInfo> comicInfos(Ref ref) {
  final comics = ref.watch(localComicsProvider);
  if (comics.hasError) throw comics.error!;
  return comics.value ?? [];
}

@riverpod
Stream<ComicPreference> comicProgress(Ref ref, String comicId) =>
    ref.watch(comicStoreProvider).watchProgress(comicId);

@riverpod
ComicPreference comicPrefWithComicId(Ref ref, {required String comicId}) =>
    ref.watch(comicProgressProvider(comicId)).value ??
    ComicPreference(comicId: comicId);

@riverpod
Stream<List<ChapterInfo>> chaptersWithComicId(
  Ref ref, {
  required String comicId,
}) => ref.watch(comicStoreProvider).watchChapters(comicId);
