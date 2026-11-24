import 'package:torrid/features/gallery/models/media_asset.dart';

typedef DuplicateMedia = ({String id, String path});
typedef DeletionCandidate = ({MediaAsset asset, String reason});

class AlbumDuplicateGroup {
  const AlbumDuplicateGroup(this.distance, this.media);

  factory AlbumDuplicateGroup.fromJson(Map<String, dynamic> json) {
    final ids = (json['media_ids'] as List).cast<String>();
    final paths = (json['files'] as List).cast<String>();
    return AlbumDuplicateGroup(json['distance'] as int, [
      for (var i = 0; i < ids.length; i++) (id: ids[i], path: paths[i]),
    ]);
  }

  final int distance;
  final List<DuplicateMedia> media;
}

class AlbumCleanupResults {
  AlbumCleanupResults.fromJson(Map<String, dynamic> json)
    : candidates = [
        for (final row in (json['items'] as List).cast<Map<String, dynamic>>())
          (
            asset: MediaAsset.fromJson(row['asset'] as Map<String, dynamic>),
            reason: row['reason'] as String,
          ),
      ],
      nextOffset = json['next_offset'] as int,
      hasMore = json['has_more'] == true,
      paused = json['paused'] == true,
      enabled = json['enabled'] == true,
      pending = json['queue']['pending'] as int,
      running = json['queue']['running'] as int,
      done = json['queue']['done'] as int,
      failed = json['queue']['failed'] as int;

  final List<DeletionCandidate> candidates;
  final int nextOffset;
  final bool hasMore;
  final bool paused;
  final bool enabled;
  final int pending;
  final int running;
  final int done;
  final int failed;
}
