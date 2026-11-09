import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/others/comic/models/chapter_info.dart';
import 'package:torrid/features/others/comic/models/comic_info.dart';
import 'package:torrid/features/others/comic/provider/box_provider.dart';
import 'package:torrid/features/others/comic/services/comic_storage.dart';
import 'package:torrid/providers/progress/progress.dart';
import 'package:torrid/providers/progress/progress_provider.dart';

part 'service_provider.g.dart';

@riverpod
Future<Map<String, dynamic>> allInfos(AllInfosRef ref) async {
  final directories = await localComicDirectories();
  final existing = ref.read(comicInfoBoxProvider).values.toList();
  final chapters = ref.read(chapterInfoBoxProvider).values.toList();
  final found = <String, ({ComicInfo comic, List<ChapterInfo> chapters})>{};
  final progress = ref.read(progressServiceProvider.notifier);
  progress.setProgress(
    Progress(
      current: 0,
      total: directories.length,
      currentMessage: '',
      message: '正在扫描漫画文件...',
    ),
  );
  try {
    for (var i = 0; i < directories.length; i++) {
      final directory = directories[i];
      final name = p.basename(directory.path);
      final downloaded = p.basename(directory.parent.path) == '.downloads';
      final matches = existing
          .where(
            (comic) => downloaded ? comic.id == name : comic.comicName == name,
          )
          .toList();
      for (final comic in matches.isEmpty ? <ComicInfo?>[null] : matches) {
        final data = await scanLocalComic(
          directory,
          existing: comic,
          existingChapters: chapters
              .where((chapter) => chapter.comicId == comic?.id)
              .toList(),
        );
        found[data.comic.id] = data;
      }
      progress.increaseProgress(current: i + 1, currentMessage: name);
    }
    return {
      'comicInfos': {
        for (final data in found.values) data.comic.id: data.comic,
      },
      'chapterInfos': {
        for (final data in found.values)
          for (final chapter in data.chapters) chapter.id: chapter,
      },
    };
  } finally {
    progress.resetStatus();
  }
}
