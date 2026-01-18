/// Comic 模块的核心业务逻辑服务
///
/// 提供漫画下载、偏好管理、元数据刷新等功能。
library;

import 'dart:io';

import 'package:hive/hive.dart';
import 'package:path/path.dart' as path;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/others/comic/models/chapter_info.dart';
import 'package:torrid/features/others/comic/models/comic_info.dart';
import 'package:torrid/features/others/comic/models/comic_preference.dart';
import 'package:torrid/features/others/comic/provider/box_provider.dart';
import 'package:torrid/features/others/comic/provider/service_provider.dart';
import 'package:torrid/features/others/comic/provider/status_provider.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';
import 'package:torrid/providers/progress/progress.dart';
import 'package:torrid/providers/progress/progress_provider.dart';
import 'package:torrid/core/services/debug/logging_service.dart';
import 'package:torrid/core/services/io/io_service.dart';

part 'notifier_provider.g.dart';

// ============================================================================
// 数据仓库
// ============================================================================

/// Comic 模块的数据仓库
/// 
/// 封装对 [ComicPreference]、[ComicInfo]、[ChapterInfo] 三个 Box 的访问。
/// 
/// **重构说明**: 原名 `Cashier`，重命名为语义更清晰的 `ComicRepository`。
class ComicRepository {
  final Box<ComicPreference> prefBox;
  final Box<ComicInfo> comicInfoBox;
  final Box<ChapterInfo> chapterInfoBox;

  const ComicRepository({
    required this.prefBox,
    required this.comicInfoBox,
    required this.chapterInfoBox,
  });
}

// ============================================================================
// Comic 服务
// ============================================================================

/// Comic 模块的核心服务
/// 
/// 提供以下功能：
/// - 阅读偏好管理
/// - 漫画下载与保存
/// - 元数据刷新
@riverpod
class ComicService extends _$ComicService {
  /// 最大并发下载数
  static const int _maxConcurrent = 5;
  
  /// 批次间延迟
  static const Duration _requestDelay = Duration(milliseconds: 100);

  @override
  ComicRepository build() {
    return ComicRepository(
      prefBox: ref.read(comicPrefBoxProvider),
      comicInfoBox: ref.read(comicInfoBoxProvider),
      chapterInfoBox: ref.read(chapterInfoBoxProvider),
    );
  }

  // --------------------------------------------------------------------------
  // 阅读偏好管理
  // --------------------------------------------------------------------------

  /// 保存漫画阅读偏好
  Future<void> putComicPref({required ComicPreference comicPref}) async {
    await state.prefBox.put(comicPref.comicId, comicPref);
    ref.invalidate(comicPrefWithComicIdProvider);
  }

  /// 修改漫画阅读偏好
  Future<void> modifyComicPref({
    required String comicId,
    int? chapterIndex,
    @Deprecated('保留仅为兼容旧数据') int? pageIndex,
    bool? isFlipMode,
  }) async {
    final comicPref = ref.read(comicPrefWithComicIdProvider(comicId: comicId));
    await state.prefBox.put(
      comicPref.comicId,
      comicPref.copyWith(
        chapterIndex: chapterIndex,
        // ignore: deprecated_member_use_from_same_package
        pageIndex: pageIndex,
        flipReading: isFlipMode,
      ),
    );
    ref.invalidate(comicPrefWithComicIdProvider);
  }

  // --------------------------------------------------------------------------
  // 漫画下载
  // --------------------------------------------------------------------------

  /// 下载整部漫画并保存到本地
  /// 
  /// 下载流程：
  /// 1. 获取下载清单
  /// 2. 创建目录结构
  /// 3. 分批下载图片（控制并发）
  /// 4. 重试失败的图片
  /// 5. 保存元数据
  Future<void> downloadAndSaveComic({required ComicInfo comicInfo}) async {
    final manifestResponse = await ref.read(
      fetcherProvider(path: "/api/comic/download/${comicInfo.id}").future,
    );
    if (manifestResponse == null || manifestResponse.statusCode != 200) {
      throw Exception("获取下载清单失败");
    }

    final chapters = <String, ChapterInfo>{};
    final failedImages = <Map<String, dynamic>>[];
    final externalPath = (await IoService.externalStorageDir).path;
    final comicRootDir = path.join("comics", comicInfo.comicName);
    final chaptersData = manifestResponse.data as List;
    
    ref.read(progressServiceProvider.notifier).setProgress(
      Progress(
        current: 0,
        total: comicInfo.chapterCount,
        currentMessage: "准备中...",
        message: "下载整本漫画中...",
      ),
    );

    try {
      await IoService.ensureDirExists(comicRootDir);

      // 收集所有图片下载任务
      final allImageTasks = <Future<int> Function()>[];
      for (final chapter in chaptersData) {
        final chapterInfo = ChapterInfo.fromJson(chapter as Map<String, dynamic>);
        chapters[chapterInfo.id] = chapterInfo;

        final chapterDir = path.join(comicRootDir, chapterInfo.dirName);
        await IoService.ensureDirExists(chapterDir);

        for (final image in chapterInfo.images) {
          allImageTasks.add(
            () => _downloadImage(
              image: image,
              chapterInfo: chapterInfo,
              comicInfo: comicInfo,
              externalPath: externalPath,
              chapterDir: chapterDir,
              failedImages: failedImages,
            ),
          );
        }
      }

      // 分批执行下载
      await _executeTasksInBatches(
        tasks: allImageTasks,
        batchSize: _maxConcurrent,
        delayBetweenBatches: _requestDelay,
      );

      // 重试失败的图片
      if (failedImages.isNotEmpty) {
        await _retryFailedImages(failedImages);
      }

      // 保存元数据
      await state.comicInfoBox.put(
        comicInfo.id,
        comicInfo.copyWith(
          coverImage: path.join(externalPath, comicInfo.coverImage),
        ),
      );
      await state.chapterInfoBox.putAll(chapters);

      if (failedImages.isNotEmpty) {
        AppLogger().warning(
          "漫画下载完成，但有${failedImages.length}张图片失败: $failedImages",
        );
      }

      ref.read(progressServiceProvider.notifier).resetStatus();
    } catch (e) {
      await IoService.clearSpecificDirectory(comicRootDir);
      await state.comicInfoBox.delete(comicInfo.id);
      await state.chapterInfoBox.deleteAll(chapters.keys);
      AppLogger().error("下载漫画核心逻辑失败: $e");
      rethrow;
    }
  }

  /// 下载单张图片
  Future<int> _downloadImage({
    required Map<String, dynamic> image,
    required ChapterInfo chapterInfo,
    required ComicInfo comicInfo,
    required String externalPath,
    required String chapterDir,
    required List<Map<String, dynamic>> failedImages,
  }) async {
    final imageUrl = "/static/${image['path']}";
    final imageFileName = path.basename(imageUrl);
    final relativePath = path.join(chapterDir, imageFileName);
    final localImagePath = path.join(externalPath, relativePath);

    try {
      final file = File(localImagePath);
      if (await file.exists()) {
        image['path'] = localImagePath;
        return chapterInfo.chapterIndex;
      }
      
      await _saveImageToLocal(imageUrl, relativePath);
      image['path'] = localImagePath;
      return chapterInfo.chapterIndex;
    } catch (e) {
      failedImages.add({
        "comicId": comicInfo.id,
        "chapterId": chapterInfo.id,
        "imageUrl": imageUrl,
        "localPath": relativePath,
        "error": e.toString(),
      });
      AppLogger().warning("单张图片下载失败: $imageUrl, 错误: $e");
      return -1;
    }
  }

  /// 分批执行任务，控制并发数和批次间延迟
  Future<void> _executeTasksInBatches({
    required List<Future<int> Function()> tasks,
    required int batchSize,
    required Duration delayBetweenBatches,
  }) async {
    final batches = <List<Future<int> Function()>>[];
    for (int i = 0; i < tasks.length; i += batchSize) {
      final end = (i + batchSize > tasks.length) ? tasks.length : i + batchSize;
      batches.add(tasks.sublist(i, end));
    }

    for (int i = 0; i < batches.length; i++) {
      final batch = batches[i];
      final results = await Future.wait(batch.map((task) => task()));
      final currChapter = results.fold(-1, (prev, elem) => elem > prev ? elem : prev);
      
      if (currChapter > ref.read(progressServiceProvider).current) {
        ref.read(progressServiceProvider.notifier).increaseProgress(
          current: currChapter,
          currentMessage: "已下载至章节 $currChapter",
        );
      }
      
      if (i < batches.length - 1) {
        await Future.delayed(delayBetweenBatches);
      }
    }
  }

  /// 重试失败的图片下载
  Future<void> _retryFailedImages(List<Map<String, dynamic>> failedImages) async {
    for (final failed in failedImages) {
      try {
        await _saveImageToLocal(
          failed['imageUrl'] as String,
          failed['localPath'] as String,
        );
        AppLogger().info("重试成功: ${failed['imageUrl']}");
      } catch (e) {
        AppLogger().error("重试失败: ${failed['imageUrl']}, 错误: $e");
      }
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  /// 将图片保存到本地存储
  Future<void> _saveImageToLocal(String url, String relativePath) async {
    final data = await ref.read(bytesFetcherProvider(path: url).future);
    if (data == null || data.statusCode != 200) {
      throw Exception("图片下载失败");
    }
    await IoService.saveImageToExternalStorage(
      relativePath: relativePath,
      bytes: data.data!,
    );
  }

  // --------------------------------------------------------------------------
  // 元数据刷新
  // --------------------------------------------------------------------------

  /// 刷新所有漫画元数据（完全重建）
  Future<void> refreshInfosAll() async {
    final infos = await ref.read(allInfosProvider.future);
    await state.comicInfoBox.clear();
    await state.chapterInfoBox.clear();

    await state.comicInfoBox.putAll(
      infos['comicInfos'] as Map<dynamic, ComicInfo>,
    );
    await state.chapterInfoBox.putAll(
      infos['chapterInfos'] as Map<dynamic, ChapterInfo>,
    );
  }

  /// 增量刷新元数据（只处理变动）
  /// 
  /// 删除目录不存在的记录，添加新发现的漫画。
  Future<void> refreshChanged() async {
    final deleted = await ref.read(deletedInfosProvider.future);
    await state.prefBox.deleteAll(deleted['prefs'] as List);
    await state.comicInfoBox.deleteAll(deleted['comics'] as List);
    await state.chapterInfoBox.deleteAll(deleted['chapters'] as List);

    final infos = await ref.read(newInfosProvider.future);
    await state.comicInfoBox.putAll(
      infos['comicInfos'] as Map<dynamic, ComicInfo>,
    );
    await state.chapterInfoBox.putAll(
      infos['chapterInfos'] as Map<dynamic, ChapterInfo>,
    );
  }
}
