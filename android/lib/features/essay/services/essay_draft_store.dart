import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:torrid/core/services/debug/logging_service.dart';
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

  Future<String> importImage(String draftId, File source) =>
      IoService.importUserImage('essay_drafts/$draftId', source);

  Future<Essay> publish(
    Essay essay,
    Future<void> Function(Essay) writeEssay,
  ) async {
    final images = <String>[];
    final imported = <String>[];
    try {
      for (final image in essay.imgs) {
        if (image.startsWith('essay_drafts/')) {
          if (!image.startsWith('essay_drafts/${essay.id}/')) {
            throw const FormatException('图片不属于当前草稿');
          }
          final key = await IoService.importUserImage(
            'img_storage/essay',
            await IoService.userFile(image),
          );
          imported.add(key);
          images.add(key);
        } else {
          images.add(image);
        }
      }
      final published = essay.copyWith(imgs: images);
      await writeEssay(published);
      return published;
    } catch (_) {
      for (final key in imported) {
        try {
          await IoService.deleteUserFile(key);
        } catch (error) {
          AppLogger().warning('清理未发布的随笔图片失败: $error');
        }
      }
      rethrow;
    }
  }

  Future<void> cleanImages(String id) =>
      IoService.deleteUserDirectory('essay_drafts/$id');
}
