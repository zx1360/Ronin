import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:torrid/core/services/io/io_service.dart';
import 'package:torrid/features/others/comic/models/chapter_info.dart';
import 'package:torrid/features/others/comic/models/comic_info.dart';
import 'package:torrid/features/others/comic/services/io_image_service.dart';

String comicDownloadPath(String id) => 'comics/.downloads/$id';

// 下载目录保留名称和章节身份，重扫文件时不依赖 Hive 是否仍有元数据。
Future<void> writeComicIndex(
  Directory directory,
  ComicInfo comic,
  List<ChapterInfo> chapters,
) async {
  await IoService.writeAtomically(
    File(p.join(directory.path, 'comic.json')),
    utf8.encode(
      jsonEncode({
        'comic': comic.toJson(),
        'chapters': [
          for (final chapter in chapters) chapter.copyWith(images: []).toJson(),
        ],
      }),
    ),
  );
}

Future<List<Directory>> localComicDirectories() async {
  final root = await IoService.offlineDirectory('comics');
  final directories = await root
      .list(followLinks: false)
      .where((entry) => entry is Directory)
      .cast<Directory>()
      .toList();
  final downloads = Directory(p.join(root.path, '.downloads'));
  final result = directories
      .where((dir) => dir.path != downloads.path)
      .toList();
  if (await downloads.exists()) {
    await for (final entry in downloads.list(followLinks: false)) {
      if (entry is Directory &&
          await File(p.join(entry.path, 'comic.json')).exists()) {
        result.add(entry);
      }
    }
  }
  return result;
}

Future<({ComicInfo comic, List<ChapterInfo> chapters})> scanLocalComic(
  Directory directory, {
  ComicInfo? existing,
  List<ChapterInfo> existingChapters = const [],
}) async {
  final index = File(p.join(directory.path, 'comic.json'));
  var known = {
    for (final chapter in existingChapters) chapter.dirName: chapter,
  };
  if (await index.exists()) {
    final data = jsonDecode(await index.readAsString()) as Map<String, dynamic>;
    existing ??= ComicInfo.fromJson(data['comic'] as Map<String, dynamic>);
    known = {
      for (final row in data['chapters'] as List)
        (row['id'] as String): ChapterInfo.fromJson(
          Map<String, dynamic>.from(row as Map),
        ),
    };
  }
  final comic =
      existing ??
      ComicInfo.newOne(
        comicName: p.basename(directory.path),
        coverImage: '',
        chapterCount: 0,
        imageCount: 0,
      );
  final chapters = <ChapterInfo>[];
  await for (final entry in directory.list(followLinks: false)) {
    if (entry is! Directory) continue;
    final name = p.basename(entry.path);
    final images = await scanImages(entry);
    final previous = known[name];
    chapters.add(
      previous != null
          ? previous.copyWith(images: images, imageCount: images.length)
          : ChapterInfo.newOne(
              comicId: comic.id,
              chapterIndex: getChapterIndex(name),
              dirName: name,
              images: images,
            ),
    );
  }
  chapters.sort((a, b) => a.chapterIndex.compareTo(b.chapterIndex));
  final images = chapters.expand((chapter) => chapter.images).toList();
  return (
    comic: comic.copyWith(
      coverImage: images.isEmpty ? '' : images.first['path'] as String,
      chapterCount: chapters.length,
      imageCount: images.length,
    ),
    chapters: chapters,
  );
}

Future<void> deleteComicFiles(
  ComicInfo comic,
  Iterable<ComicInfo> comics,
  Iterable<ChapterInfo> chapters,
) async {
  await IoService.deleteOfflineDirectory(comicDownloadPath(comic.id));
  if (comic.comicName.isEmpty ||
      comic.comicName == '.' ||
      comic.comicName == '..' ||
      RegExp(r'[\\/:\x00]').hasMatch(comic.comicName) ||
      comic.comicName == '.downloads' ||
      comics.any(
        (other) => other.id != comic.id && other.comicName == comic.comicName,
      )) {
    return;
  }
  final root = await IoService.offlineDirectory('comics');
  final legacy = Directory(IoService.safePath(root, comic.comicName));
  final shared = chapters
      .where((chapter) => chapter.comicId != comic.id)
      .expand((chapter) => chapter.images)
      .any((image) => p.isWithin(legacy.path, image['path'] as String));
  if (!shared && await legacy.exists()) {
    await legacy.delete(recursive: true);
  }
}

int getChapterIndex(String name) => int.tryParse(name.split('_').first) ?? 0;

String getChapterTitle(String name) => name.substring(name.indexOf('_') + 1);
