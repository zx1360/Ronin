import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/others/comic/models/chapter_info.dart';
import 'package:torrid/features/others/comic/models/comic_info.dart';
import 'package:torrid/features/others/comic/models/comic_preference.dart';
import 'package:torrid/features/others/comic/provider/box_provider.dart';

part 'status_provider.g.dart';

// ----源数据----
// comicPref
@riverpod
List<ComicPreference> comicPrefs(ComicPrefsRef ref){
  final asyncVal = ref.watch(comicPrefStreamProvider);
  if (asyncVal.hasError) {
    throw asyncVal.error!;
  }
  return asyncVal.asData?.value ?? [];
}

// comicInfo
@riverpod
List<ComicInfo> comicInfos(ComicInfosRef ref){
  final asyncVal = ref.watch(comicInfoStreamProvider);
  if (asyncVal.hasError) {
    throw asyncVal.error!;
  }
  return asyncVal.asData?.value ?? [];
}

// chapterInfo
@riverpod
List<ChapterInfo> chapterInfos(ChapterInfosRef ref){
  final asyncVal = ref.watch(chapterInfoStreamProvider);
  if (asyncVal.hasError) {
    throw asyncVal.error!;
  }
  return asyncVal.asData?.value ?? [];
}
