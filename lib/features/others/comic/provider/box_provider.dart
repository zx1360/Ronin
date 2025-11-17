import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/others/comic/models/chapter_info.dart';
import 'package:torrid/features/others/comic/models/comic_info.dart';
import 'package:torrid/features/others/comic/models/comic_preference.dart';
import 'package:torrid/services/storage/hive_service.dart';

part 'box_provider.g.dart';

// comicPreference  漫画阅读偏好
@riverpod
Box<ComicPreference> comicPrefBox(ComicPrefBoxRef ref) {
  return Hive.box(HiveService.comicPrefBoxName);
}

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

// comicInfo  漫画信息
@riverpod
Box<ComicInfo> comicInfoBox(ComicInfoBoxRef ref) {
  return Hive.box(HiveService.comicBoxName);
}

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

// chapterInfo  章节信息
@riverpod
Box<ChapterInfo> chapterInfoBox(ChapterInfoBoxRef ref) {
  return Hive.box(HiveService.chapterBoxName);
}

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
