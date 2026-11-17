import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:torrid/core/services/storage/app_database.dart';

import 'trace_scene.dart';

typedef TraceDetails = ({String? itemId, Set<String> tagIds, String note});

const emptyTraceDetails = (itemId: null, tagIds: <String>{}, note: '');

class TraceData {
  TraceData(this.scenes, this.items, this.tags, this.sessions);

  static const otherScene = TraceScene(
    id: traceOtherSceneId,
    name: traceOtherSceneName,
    color: traceDefaultColor,
    archived: false,
    version: 0,
  );

  final List<TraceScene> scenes;
  final List<TraceItem> items;
  final List<TraceTag> tags;
  final List<TraceSession> sessions;

  late final sceneById = {for (final scene in scenes) scene.id: scene};
  late final itemById = {for (final item in items) item.id: item};
  late final tagById = {for (final tag in tags) tag.id: tag};
  late final _touchedScenes = {
    ...items.map((item) => item.sceneId),
    for (final session in sessions)
      if (!session.deleted) session.sceneId,
  };
  late final catalogScenes = scenes
      .where(
        (scene) =>
            scene.deletion == null &&
            (scene.version != 0 ||
                !isTraceLegacyPreset(scene.id) ||
                _touchedScenes.contains(scene.id)),
      )
      .toList();

  // 保留原始场景与事项关系，删除标记统一决定回顾归类。
  TraceScene historySceneFor(String sceneId) {
    final scene = sceneById[sceneId]!;
    return scene.deletion == TraceSceneDeletion.keep.name ? otherScene : scene;
  }

  TraceScene? historySceneById(String? sceneId) =>
      sceneId == traceOtherSceneId ? otherScene : sceneById[sceneId];

  late final historyScenes = [
    ...catalogScenes,
    if (history.any(
      (row) => historySceneFor(row.sceneId).id == traceOtherSceneId,
    ))
      otherScene,
  ];

  late final _historicalItems = {for (final row in history) row.itemId};

  Iterable<TraceItem> historyItemsIn(String? sceneId) => items.where((item) {
    final deletion = sceneById[item.sceneId]?.deletion;
    if (deletion == TraceSceneDeletion.erase.name ||
        (deletion != null && !_historicalItems.contains(item.id))) {
      return false;
    }
    return sceneId == null || historySceneFor(item.sceneId).id == sceneId;
  });
  final _tagsBySession = <String, Set<String>>{};
  Set<String> tagsFor(TraceSession session) => _tagsBySession.putIfAbsent(
    session.id,
    () => decodeTraceTags(session.tagIdsJson),
  );
  late final active = sessions
      .where((s) => s.endedMs == null && !s.deleted)
      .toList();
  late final history = sessions
      .where((s) => s.endedMs != null && !s.deleted)
      .toList();
  late final totals = _totals();

  ({int all, Map<String, int> scenes}) _totals() {
    var all = 0;
    final scenes = <String, int>{};
    for (final session in history) {
      final duration = session.endedMs! - session.startedMs;
      scenes.update(
        historySceneFor(session.sceneId).id,
        (ms) => ms + duration,
        ifAbsent: () => duration,
      );
      all += duration;
    }
    return (all: all, scenes: scenes);
  }

  List<TraceItem> itemsIn(String sceneId) =>
      items.where((item) => item.sceneId == sceneId).toList();

  factory TraceData.fromJson(Map<String, dynamic> json) {
    if (json['format_version'] != 1) {
      throw const FormatException('时迹备份版本不兼容');
    }
    List<T> rows<T>(String key, T Function(Map<String, dynamic>) parse) =>
        (json[key] as List)
            .map((row) => parse(row as Map<String, dynamic>))
            .toList();
    final data = TraceData(
      rows('scenes', (row) {
        final color = switch (row['color']) {
          int value when value >= 0 && value <= 0xffffffff => traceColorFromRgb(
            value,
          ),
          String value => traceColorHex(value),
          _ => null,
        };
        if (color == null) throw const FormatException('时迹备份包含无效的场景颜色');
        return TraceScene.fromJson({...row, 'color': color});
      }),
      rows('items', TraceItem.fromJson),
      rows('tags', TraceTag.fromJson),
      rows('sessions', (row) {
        if (!row.containsKey('ended_ms')) throw const FormatException('缺少结束时间');
        return TraceSession.fromJson(_withoutClock(row));
      }),
    );
    if (data.sceneById.length != data.scenes.length ||
        data.itemById.length != data.items.length ||
        data.tagById.length != data.tags.length ||
        data.sessions.map((s) => s.id).toSet().length != data.sessions.length ||
        data.scenes.any(
          (s) =>
              s.id.isEmpty ||
              s.id == traceOtherSceneId ||
              s.name.trim().isEmpty ||
              s.version < 0 ||
              (s.deletion != null &&
                  (s.deletion != TraceSceneDeletion.keep.name &&
                      s.deletion != TraceSceneDeletion.erase.name)),
        ) ||
        data.items.any(
          (i) =>
              i.id.isEmpty ||
              i.name.trim().isEmpty ||
              i.version < 0 ||
              !data.sceneById.containsKey(i.sceneId),
        ) ||
        data.tags.any(
          (t) => t.id.isEmpty || t.name.trim().isEmpty || t.version < 0,
        )) {
      throw const FormatException('时迹备份包含无效分类');
    }
    for (final session in data.sessions) {
      if (session.id.isEmpty ||
          session.version < 0 ||
          session.startedMs < 0 ||
          (session.endedMs != null && session.endedMs! < session.startedMs) ||
          !data.sceneById.containsKey(session.sceneId) ||
          (session.itemId != null &&
              data.itemById[session.itemId]?.sceneId != session.sceneId) ||
          data.tagsFor(session).any((id) => !data.tagById.containsKey(id))) {
        throw const FormatException('时迹备份包含无效计时记录');
      }
    }
    return data;
  }

  Map<String, dynamic> toJson() => {
    'format_version': 1,
    'scenes': scenes.map((row) => row.toJson()).toList(),
    'items': items.map((row) => row.toJson()).toList(),
    'tags': tags.map((row) => row.toJson()).toList(),
    'sessions': sessions.map((row) => _withoutClock(row.toJson())).toList(),
  };

  static Map<String, dynamic> _withoutClock(Map<String, dynamic> row) =>
      {...row}
        ..remove('boot_key')
        ..remove('anchor_elapsed_ms')
        ..remove('anchor_duration_ms')
        ..remove('anchor_wall_ms');
}

extension TraceSessionClock on TraceSession {
  TraceSession withClockOf(TraceSession? source) => copyWith(
    bootKey: Value(source?.bootKey),
    anchorElapsedMs: Value(source?.anchorElapsedMs),
    anchorDurationMs: Value(source?.anchorDurationMs),
    anchorWallMs: Value(source?.anchorWallMs),
  );
}

Set<String> decodeTraceTags(String value) =>
    (jsonDecode(value) as List).cast<String>().toSet();
