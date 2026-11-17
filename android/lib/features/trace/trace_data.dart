import 'dart:convert';

import 'package:torrid/core/services/storage/app_database.dart';

class TraceData {
  TraceData(this.scenes, this.items, this.tags, this.sessions);

  final List<TraceScene> scenes;
  final List<TraceItem> items;
  final List<TraceTag> tags;
  final List<TraceSession> sessions;

  late final sceneById = {for (final scene in scenes) scene.id: scene};
  late final itemById = {for (final item in items) item.id: item};
  late final tagById = {for (final tag in tags) tag.id: tag};
  late final tagIdsBySession = {
    for (final session in sessions)
      session.id: decodeTraceTags(session.tagIdsJson),
  };
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
        session.sceneId,
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
      rows('scenes', TraceScene.fromJson),
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
              s.name.trim().isEmpty ||
              s.version < 0 ||
              s.color < 0 ||
              s.color > 0xffffffff,
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
          data.tagIdsBySession[session.id]!.any(
            (id) => !data.tagById.containsKey(id),
          )) {
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
        ..remove('anchor_duration_ms');
}

Set<String> decodeTraceTags(String value) =>
    (jsonDecode(value) as List).cast<String>().toSet();
