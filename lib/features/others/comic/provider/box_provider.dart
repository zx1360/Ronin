/// Comic 模块的 Hive Box 提供者
///
/// 提供对 [ComicPreference]、[ComicInfo]、[ChapterInfo] 三种数据的 Box 访问和响应式流。
library;

import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/others/comic/models/chapter_info.dart';
import 'package:torrid/features/others/comic/models/comic_info.dart';
import 'package:torrid/features/others/comic/models/comic_preference.dart';
import 'package:torrid/core/services/storage/hive_service.dart';

part 'box_provider.g.dart';

// ============================================================================
// ComicPreference Box & Stream
// ============================================================================

/// 漫画阅读偏好的 Hive Box
@riverpod
Box<ComicPreference> comicPrefBox(ComicPrefBoxRef ref) {
  return Hive.box(HiveService.comicPrefBoxName);
}

/// 漫画阅读偏好的响应式流
@riverpod
Stream<List<ComicPreference>> comicPrefStream(ComicPrefStreamRef ref) async* {
  final box = ref.read(comicPrefBoxProvider);
  yield box.values.toList();
  await for (final event in box.watch()) {
    if (event.deleted || event.value != null) {
      yield box.values.toList();
    }
  }
}

// ============================================================================
// ComicInfo Box & Stream
// ============================================================================

/// 漫画信息的 Hive Box
@riverpod
Box<ComicInfo> comicInfoBox(ComicInfoBoxRef ref) {
  return Hive.box(HiveService.comicBoxName);
}

/// 漫画信息的响应式流
@riverpod
Stream<List<ComicInfo>> comicInfoStream(ComicInfoStreamRef ref) async* {
  final box = ref.read(comicInfoBoxProvider);
  yield box.values.toList();
  await for (final event in box.watch()) {
    if (event.deleted || event.value != null) {
      yield box.values.toList();
    }
  }
}

// ============================================================================
// ChapterInfo Box & Stream
// ============================================================================

/// 章节信息的 Hive Box
@riverpod
Box<ChapterInfo> chapterInfoBox(ChapterInfoBoxRef ref) {
  return Hive.box(HiveService.chapterBoxName);
}

/// 章节信息的响应式流
@riverpod
Stream<List<ChapterInfo>> chapterInfoStream(ChapterInfoStreamRef ref) async* {
  final box = ref.watch(chapterInfoBoxProvider);
  yield box.values.toList();
  await for (final event in box.watch()) {
    if (event.deleted || event.value != null) {
      yield box.values.toList();
    }
  }
}
