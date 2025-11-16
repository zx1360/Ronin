import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/others/comic/models/chapter_info.dart';
import 'package:torrid/features/others/comic/models/comic_info.dart';
import 'package:torrid/features/others/comic/models/comic_preference.dart';
import 'package:torrid/features/others/comic/provider/status_provider.dart';

part 'content_provider.g.dart';

@riverpod
class ComicContent extends _$ComicContent {
  @override
  Map<String, dynamic> build() {
    return {"comicInfo": null, "chapterInfos": null, "comicPref": null};
  }

  void switchContent({
    required ComicInfo comicInfo,
    required List<ChapterInfo> chapterInfos,
  }) {
    final comicPref =
        ref.read(comicPrefWithComicIdProvider(comicId: comicInfo.id)) ??
        ComicPreference(comicId: comicInfo.id, chapterIndex: 0, pageIndex: 0);
    state = {
      "comicInfo": comicInfo,
      "chapterInfos": chapterInfos,
      "comicPref": comicPref,
    };
  }
}
