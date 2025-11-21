import 'package:hive/hive.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/others/comic/models/chapter_info.dart';
import 'package:torrid/features/others/comic/models/comic_info.dart';
import 'package:torrid/features/others/comic/models/comic_preference.dart';
import 'package:torrid/features/others/comic/provider/box_provider.dart';
import 'package:torrid/features/others/comic/provider/service_provider.dart';
import 'package:torrid/features/others/comic/provider/status_provider.dart';

part 'notifier_provider.g.dart';

class Cashier {
  final Box<ComicPreference> prefBox;
  final Box<ComicInfo> comicInfoBox;
  final Box<ChapterInfo> chapterInfoBox;

  Cashier({
    required this.prefBox,
    required this.comicInfoBox,
    required this.chapterInfoBox,
  });
}

@riverpod
class ComicService extends _$ComicService {
  @override
  Cashier build() {
    return Cashier(
      prefBox: ref.read(comicPrefBoxProvider),
      comicInfoBox: ref.read(comicInfoBoxProvider),
      chapterInfoBox: ref.read(chapterInfoBoxProvider),
    );
  }

  // --偏好相关
  Future<void> putComicPref({required ComicPreference comicPref}) async {
    await state.prefBox.put(comicPref.comicId, comicPref);
    ref.invalidate(comicPrefWithComicIdProvider);
  }

  // 变动偏好.
  Future<void> modifyComicPref({
    required String comicId,
    int? chapterIndex,
    int? pageIndex,
    bool? isFlipMode,
  }) async {
    final comicPref = ref.read(comicPrefWithComicIdProvider(comicId: comicId));
    await state.prefBox.put(
      comicPref.comicId,
      comicPref.copyWith(
        chapterIndex: chapterIndex,
        pageIndex: pageIndex,
        flipReading: isFlipMode,
      ),
    );
    ref.invalidate(comicPrefWithComicIdProvider);
  }

  // ----初始化漫画元数据信息----
  // 初始化所有漫画文件元数据
  Future<void> refreshInfosAll() async {
    // # 获取comicInfo信息
    final infos = await ref.read(allInfosProvider.future);
    await state.comicInfoBox.clear();
    await state.chapterInfoBox.clear();

    await state.comicInfoBox.putAll(infos['comicInfos']);
    await state.chapterInfoBox.putAll(infos['chapterInfos']);
  }

  // 仅变动更新(新增未记录的、删去目录不存在的)
  Future<void> refreshChanged() async {
    // 删去不存在的.
    final deleted = ref.read(deletedInfosProvider);
    await state.prefBox.deleteAll(deleted['prefs']);
    await state.comicInfoBox.deleteAll(deleted['comics']);
    await state.chapterInfoBox.deleteAll(deleted['chapters']);
    // 加入未记录的.
    final infos = await ref.read(newInfosProvider.future);
    await state.comicInfoBox.putAll(infos['comicInfos']);
    await state.chapterInfoBox.putAll(infos['chapterInfos']);
  }
}
