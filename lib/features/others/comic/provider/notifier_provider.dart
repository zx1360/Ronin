import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:path/path.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/others/comic/models/chapter_info.dart';
import 'package:torrid/features/others/comic/models/comic_info.dart';
import 'package:torrid/features/others/comic/models/comic_preference.dart';
import 'package:torrid/features/others/comic/provider/box_provider.dart';
import 'package:torrid/features/others/comic/provider/service_provider.dart';
import 'package:torrid/features/others/comic/provider/status_provider.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';
import 'package:torrid/services/io/io_service.dart';

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

  // 下载整部漫画并保存.
  Future<void> downloadAndSaveComic({required ComicInfo comicInfo}) async {
    final chaptersResponse = await ref.read(
      fetcherProvider(path: "/api/comic/comic-info/${comicInfo.id}").future,
    );
    if (chaptersResponse == null || chaptersResponse.statusCode != 200) {
      throw Exception("获取章节信息失败");
    }
    final Map<String, ChapterInfo> chapters = {};
    try {
      state.comicInfoBox.put(comicInfo.id, comicInfo);
      final List<Future> task = [];

      for (final chapter in chaptersResponse.data) {
        ChapterInfo chapterInfo = ChapterInfo.fromJson(chapter);
        final imagesResponse = await ref.read(
          fetcherProvider(
            path: "/api/comic/chapter-info/${chapterInfo.id}",
          ).future,
        );
        if (imagesResponse == null || imagesResponse.statusCode != 200) {
          throw Exception("获取章节图片信息失败");
        }

        final List<Map<String, dynamic>> images = [];
        for (final image in imagesResponse.data) {
          images.add({
            "path": image['path'],
            "width": image['width'],
            "height": image['height'],
          });
        }
        print(images.runtimeType);
        print(imagesResponse.data.runtimeType);
        print("__1");
        chapterInfo = chapterInfo.copyWith(images: images);
        print("__2");
        chapters[chapterInfo.id] = chapterInfo;
        task.add(
          Future.wait(
            chapterInfo.images.map((image) async {
              final imageUrl = "/static/${image['path']}";
              final relativePath =
                  "/comics/${comicInfo.comicName}/${chapterInfo.dirName}/${imageUrl.split('/').last}";
              saveImageToLocal(imageUrl, relativePath);
            }),
          ),
        );
        print("__3");
        for (final image in chapterInfo.images) {
          print("XXXX");
          image['path'] = join(
            (await IoService.externalStorageDir).path,
            image['path'],
          );
          print("WWWW");
        }
      }

      print("__4");
      await Future.wait(task);
      await state.chapterInfoBox.putAll(chapters);
    } catch (e) {
      await IoService.clearSpecificDirectory("/comics/${comicInfo.comicName}");
      await state.comicInfoBox.delete(comicInfo.id);
      await state.chapterInfoBox.deleteAll(chapters.keys);
      throw Exception("下载漫画失败: $e");
    }
  }

  // 讲某图片保存到某某路径.
  Future<void> saveImageToLocal(String url, String relativePath) async {
    final data = await ref.read(bytesFetcherProvider(path: url).future);
    if (data == null || data.statusCode != 200) {
      throw Exception("图片下载失败");
    }
    await IoService.saveImageToExternalStorage(
      relativePath: relativePath,
      bytes: data.data!,
    );
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
    final deleted = await ref.read(deletedInfosProvider.future);
    await state.prefBox.deleteAll(deleted['prefs']);
    await state.comicInfoBox.deleteAll(deleted['comics']);
    await state.chapterInfoBox.deleteAll(deleted['chapters']);
    // 加入未记录的.
    final infos = await ref.read(newInfosProvider.future);
    await state.comicInfoBox.putAll(infos['comicInfos']);
    await state.chapterInfoBox.putAll(infos['chapterInfos']);
  }
}
