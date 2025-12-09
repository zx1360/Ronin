import 'dart:io';

import 'package:hive/hive.dart';
import 'package:path/path.dart';
import 'package:path/path.dart' as path;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/others/comic/models/chapter_info.dart';
import 'package:torrid/features/others/comic/models/comic_info.dart';
import 'package:torrid/features/others/comic/models/comic_preference.dart';
import 'package:torrid/features/others/comic/provider/box_provider.dart';
import 'package:torrid/features/others/comic/provider/service_provider.dart';
import 'package:torrid/features/others/comic/provider/status_provider.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';
import 'package:torrid/services/debug/logging_service.dart';
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
  // TODO: 加载态反馈/ 进度.
  final int _maxConcurrent = 5; // 最大并发下载数
  final Duration _requestDelay = Duration(milliseconds: 200); // 批次间延迟

  Future<void> downloadAndSaveComic({required ComicInfo comicInfo}) async {
    // 1. 获取下载清单
    final manifestResponse = await ref.read(
      fetcherProvider(path: "/api/comic/download/${comicInfo.id}").future,
    );
    if (manifestResponse == null || manifestResponse.statusCode != 200) {
      throw Exception("获取下载清单失败");
    }

    final Map<String, ChapterInfo> chapters = {};
    final List<Map<String, dynamic>> failedImages = []; // 记录失败的图片
    final externalPath = (await IoService.externalStorageDir).path;
    final comicRootDir = path.join("comics", comicInfo.comicName);

    try {
      // 2. 初始化目录
      await IoService.ensureDirExists(comicRootDir);

      // 3. 遍历章节，收集所有图片下载任务
      final List<Future<void>> allImageTasks = [];
      for (final chapter in manifestResponse.data) {
        final ChapterInfo chapterInfo = ChapterInfo.fromJson(chapter);
        chapters[chapterInfo.id] = chapterInfo;

        // 创建章节目录
        final chapterDir = path.join(comicRootDir, chapterInfo.dirName);
        await IoService.ensureDirExists(chapterDir);

        // 收集当前章节的图片下载任务
        for (final image in chapterInfo.images) {
          final imageUrl = "/static/${image['path']}";
          final imageFileName = path.basename(imageUrl);
          final relativePath = path.join(chapterDir, imageFileName);
          final localImagePath = path.join(externalPath, relativePath);

          // 包装下载任务：捕获单张图片失败，不终止整体
          Future<void> imageTask() async {
            try {
              // 先检查文件是否已存在（避免重复下载）
              final file = File(localImagePath);
              if (await file.exists()) {
                image['path'] = localImagePath; // 已存在，直接更新路径
                return;
              }
              // 执行下载
              await saveImageToLocal(imageUrl, relativePath);
              image['path'] = localImagePath; // 更新为本地路径
            } catch (e) {
              // 单张图片失败：记录失败信息，不抛错
              failedImages.add({
                "comicId": comicInfo.id,
                "chapterId": chapterInfo.id,
                "imageUrl": imageUrl,
                "localPath": relativePath,
                "error": e.toString(),
              });
              AppLogger().warning("单张图片下载失败: $imageUrl, 错误: $e");
            }
          }

          allImageTasks.add(imageTask());
        }
      }

      // 4. 分批执行下载任务（控制并发+延迟）
      await _executeTasksInBatches(
        tasks: allImageTasks,
        batchSize: _maxConcurrent,
        delayBetweenBatches: _requestDelay,
      );

      // 4.5重试下载失败的.
      if (failedImages.isNotEmpty) {
        await _retryFailedImages(failedImages);
      }

      // 5. 持久化数据（无论是否有部分失败，已成功的都保存）
      await state.comicInfoBox.put(
        comicInfo.id,
        comicInfo.copyWith(
          coverImage: path.join(externalPath, comicInfo.coverImage),
        ),
      );
      await state.chapterInfoBox.putAll(chapters);

      // 6. 提示失败的图片（可选：弹窗/日志）
      if (failedImages.isNotEmpty) {
        AppLogger().warning(
          "漫画下载完成，但有${failedImages.length}张图片失败: $failedImages",
        );
        // 可在这里触发失败图片的重试逻辑
        // await _retryFailedImages(failedImages);
      }
    } catch (e) {
      // 仅当初始化/目录创建等核心逻辑失败时，清空目录
      await IoService.clearSpecificDirectory(comicRootDir);
      await state.comicInfoBox.delete(comicInfo.id);
      await state.chapterInfoBox.deleteAll(chapters.keys);
      AppLogger().error("下载漫画核心逻辑失败: $e");
      rethrow; // 抛出核心错误，上层可捕获提示用户
    }
  }

  /// 分批执行任务，控制并发数+批次间延迟
  Future<void> _executeTasksInBatches({
    required List<Future<void>> tasks,
    required int batchSize,
    required Duration delayBetweenBatches,
  }) async {
    // 分割任务为批次
    final batches = <List<Future<void>>>[];
    for (int i = 0; i < tasks.length; i += batchSize) {
      final end = i + batchSize > tasks.length ? tasks.length : i + batchSize;
      batches.add(tasks.sublist(i, end));
    }

    // 逐批执行
    for (int i = 0; i < batches.length; i++) {
      final batch = batches[i];
      await Future.wait(batch); // 等待当前批次完成
      // 最后一批不需要延迟
      if (i < batches.length - 1) {
        await Future.delayed(delayBetweenBatches);
      }
    }
  }

  /// （可选）重试失败的图片
  Future<void> _retryFailedImages(
    List<Map<String, dynamic>> failedImages,
  ) async {
    for (final failed in failedImages) {
      try {
        await saveImageToLocal(failed['imageUrl'], failed['localPath']);
        AppLogger().info("重试成功: ${failed['imageUrl']}");
      } catch (e) {
        AppLogger().error("重试失败: ${failed['imageUrl']}, 错误: $e");
      }
      await Future.delayed(Duration(milliseconds: 50)); // 重试间隔
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
