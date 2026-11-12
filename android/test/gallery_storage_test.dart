import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torrid/core/services/storage/app_database.dart';
import 'package:torrid/features/others/gallery/models/batch_data.dart';
import 'package:torrid/features/others/gallery/models/media_asset.dart';
import 'package:torrid/features/others/gallery/models/media_tag_link.dart';
import 'package:torrid/features/others/gallery/models/tag.dart';
import 'package:torrid/features/others/gallery/services/gallery_api_service.dart';
import 'package:torrid/features/others/gallery/services/gallery_database_service.dart';

void main() {
  test('Gallery 回传队列和工作副本同库保存，确认前不可清理或换库', () async {
    final dir = await Directory.systemTemp.createTemp('torrid-gallery-');
    final file = File('${dir.path}/test.sqlite');
    var db = AppDatabase(NativeDatabase.createInBackground(file));
    addTearDown(() async {
      await db.close();
      await dir.delete(recursive: true);
    });
    var gallery = GalleryDatabaseService(db);
    final date = DateTime.utc(2026, 3, 1);
    MediaAsset asset(String id, int order, {String? groupId}) => MediaAsset(
      id: id,
      createdAt: date,
      updatedAt: date,
      capturedAt: date.add(Duration(seconds: order)),
      filePath: '$id.jpg',
      hash: id,
      groupId: groupId,
    );
    final batch = BatchData(
      medias: [
        asset('first', 0),
        asset('lead', 1),
        asset('member', 2, groupId: 'lead'),
      ],
      tags: [
        Tag(
          id: 'tag',
          createdAt: date,
          updatedAt: date,
          name: '标签',
          fullPath: '标签',
        ),
      ],
      links: [MediaTagLink(mediaId: 'member', tagId: 'tag')],
    );
    await gallery.bindLibrary('one');
    await gallery.storeBatch(batch);
    await expectLater(
      gallery.recordOperation('tags', {
        'media_id': 'member',
        'tag_ids': ['missing'],
      }),
      throwsA(anything),
    );
    expect(await gallery.operations(), isEmpty);
    expect(await gallery.getTagIdsForMedia('member'), ['tag']);
    final local = (await gallery.getMediaAssetById('lead'))!;
    expect(
      Uri.parse(galleryMediaPath(local, 'file')).queryParameters['library_id'],
      'one',
    );
    expect(local.toJson().containsKey('local_library_id'), isFalse);

    final op = await gallery.recordOperation('patch', {
      'media_ids': ['lead'],
      'is_deleted': true,
    });
    expect(await gallery.watchProcessedStats().first, (
      mediaCount: 2,
      deletedCount: 1,
    ));
    expect((await gallery.getMediaAssetById('member'))!.isDeleted, isTrue);
    await expectLater(gallery.bindLibrary('two'), throwsStateError);
    await expectLater(
      gallery.deleteProcessedData(['lead', 'member']),
      throwsStateError,
    );
    await db.close();

    db = AppDatabase(NativeDatabase.createInBackground(file));
    gallery = GalleryDatabaseService(db);
    expect(await gallery.libraryId(), 'one');
    expect((await gallery.operations(pendingOnly: true)).single.seq, op.seq);
    expect((await gallery.getMediaAssetById('lead'))!.isDeleted, isTrue);
    await gallery.acknowledge(op.seq);
    final ids = (await gallery.getProcessedAssets())
        .map((asset) => asset.id)
        .toList();
    final processed = await gallery.recordOperation('processed', {
      'media_ids': ids,
      'request_id': 'test',
    });
    await expectLater(gallery.deleteProcessedData(ids), throwsStateError);
    expect((await gallery.operations()).last.body['request_id'], 'test');
    await gallery.deleteProcessedData(ids, confirmedSequence: processed.seq);
    expect(await gallery.operations(), isEmpty);
    expect(await gallery.getMediaAssets(), isEmpty);
    expect(await gallery.watchMediaIdsWithTags().first, isEmpty);

    await gallery.clearAllData();
    await gallery.bindLibrary('two');
    expect(await gallery.watchCurrentIndex().first, 0);
  });
}
