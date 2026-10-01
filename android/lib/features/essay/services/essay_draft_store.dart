import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import 'package:torrid/core/services/io/io_service.dart';
import 'package:torrid/core/services/storage/hive_service.dart';
import 'package:torrid/features/essay/models/essay.dart';
import 'package:torrid/features/essay/models/essay_draft.dart';

final essayDraftStoreProvider = Provider(
  (ref) => EssayDraftStore(Hive.box<String>(HiveService.essayDraftBoxName)),
);

final essayDraftsProvider = StreamProvider.autoDispose<List<EssayDraft>>((
  ref,
) async* {
  final store = ref.watch(essayDraftStoreProvider);
  yield store.all();
  await for (final _ in store.box.watch()) {
    yield store.all();
  }
});

class EssayDraftStore {
  final Box<String> box;
  Future<void> _pending = Future.value();

  EssayDraftStore(this.box);

  List<EssayDraft> all() =>
      box.values
          .map(
            (raw) =>
                EssayDraft.fromJson(jsonDecode(raw) as Map<String, dynamic>),
          )
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  EssayDraft? forEssay(String id) {
    final raw = box.get(id);
    return raw == null
        ? null
        : EssayDraft.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final result = _pending.then((_) => action());
    _pending = result.catchError((Object _) {});
    return result;
  }

  Future<void> save(EssayDraft draft) {
    final raw = jsonEncode(draft.toJson());
    return _enqueue(() => box.put(draft.essay.id, raw));
  }

  Future<void> remove(String id) => _enqueue(() => box.delete(id));

  Future<void> flush() => _enqueue(box.flush);

  // 草稿图片独立存放；同步正式随笔时不会清理到它们。
  Future<String> importImage(String draftId, File source) async {
    final relative =
        'essay_drafts/$draftId/${DateTime.now().microsecondsSinceEpoch}${p.extension(source.path)}';
    final file = File(
      p.join((await IoService.externalStorageDir).path, relative),
    );
    await file.parent.create(recursive: true);
    await source.copy(file.path);
    return relative;
  }

  Future<Essay> publishImages(Essay essay) async {
    if (!essay.imgs.any((image) => image.startsWith('essay_drafts/'))) {
      return essay;
    }
    final root = await IoService.externalStorageDir;
    final images = <String>[];
    for (final image in essay.imgs) {
      if (!image.startsWith('essay_drafts/${essay.id}/')) {
        images.add(image);
        continue;
      }
      final relative =
          'img_storage/essay/draft_${essay.id}_${p.basename(image)}';
      final target = File(p.join(root.path, relative));
      await target.parent.create(recursive: true);
      await File(p.join(root.path, image)).copy(target.path);
      images.add(relative);
    }
    return essay.copyWith(imgs: images);
  }

  Future<void> cleanImages(String id) async {
    final root = p.normalize((await IoService.externalStorageDir).path);
    final directory = Directory(p.join(root, 'essay_drafts', id));
    if (!p.isWithin(
      p.join(root, 'essay_drafts'),
      p.normalize(directory.path),
    )) {
      throw const FormatException('无效的草稿路径');
    }
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}
