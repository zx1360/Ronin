import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:torrid/core/models/message.dart';
import 'package:torrid/core/models/mood.dart';
import 'package:torrid/core/services/storage/app_database.dart';
import 'package:torrid/core/services/storage/user_data_sync.dart';
import 'package:torrid/features/essay/models/essay.dart';
import 'package:torrid/features/essay/models/label.dart';
import 'package:torrid/features/essay/models/label_tree.dart';
import 'package:torrid/features/essay/services/essay_contract.dart';

class EssayStore {
  EssayStore(this.db);

  final AppDatabase db;

  JoinedSelectStatement<HasResultSet, dynamic> _essayQuery([Set<String>? ids]) {
    final entries = db.essayEntries;
    final links = db.essayLinks;
    final query =
        db.select(entries).join([
          leftOuterJoin(links, entries.id.equalsExp(links.essayId)),
        ])..orderBy([
          OrderingTerm.desc(entries.date),
          OrderingTerm.asc(entries.id),
          OrderingTerm.asc(links.position),
        ]);
    if (ids != null) query.where(entries.id.isIn(ids));
    return query;
  }

  List<Essay> _readEssays(List<TypedResult> results) {
    final entries = <String, EssayEntry>{};
    final labels = <String, List<String>>{};
    for (final result in results) {
      final entry = result.readTable(db.essayEntries);
      entries[entry.id] = entry;
      final link = result.readTableOrNull(db.essayLinks);
      if (link != null) (labels[entry.id] ??= []).add(link.labelId);
    }
    return [
      for (final row in entries.values)
        Essay(
          id: row.id,
          date: row.date.toLocal(),
          title: row.title,
          content: row.content,
          wordCount: row.wordCount,
          imgs: (jsonDecode(row.imgs) as List).cast<String>(),
          labels: labels[row.id] ?? [],
          messages: [
            for (final json in jsonDecode(row.messages) as List)
              Message.fromJson(json as Map<String, dynamic>),
          ],
          mood: const MoodTypeConverter().fromJson(row.mood),
          createdAt: row.createdAt,
          updatedAt: row.updatedAt,
          labelsUpdatedAt: row.labelsUpdatedAt,
        ),
    ];
  }

  Stream<List<Essay>> watchEssays() => _essayQuery().watch().map(_readEssays);

  Stream<Essay?> watchEssay(String id) =>
      _essayQuery({id}).watch().map((rows) => _readEssays(rows).singleOrNull);

  Future<Essay?> essay(String id) async =>
      _readEssays(await _essayQuery({id}).get()).singleOrNull;

  Future<List<Essay>> essays() async => _readEssays(await _essayQuery().get());

  Future<List<String>> hiddenEssayIds() async => [
    for (final row
        in await db
            .customSelect(
              """
      WITH RECURSIVE hidden(id) AS (
        SELECT id FROM essay_labels WHERE id = ? OR (parent_id IS NULL AND name = '隐藏')
        UNION SELECT labels.id FROM essay_labels labels JOIN hidden ON labels.parent_id = hidden.id
      )
      SELECT DISTINCT essay_id FROM essay_links JOIN hidden ON essay_links.label_id = hidden.id
      """,
              variables: [const Variable(Label.hiddenId)],
            )
            .get())
      row.read<String>('essay_id'),
  ];

  List<Label> _readLabels(List<EssayLabel> rows) => [
    for (final row in rows)
      Label(
        id: row.id,
        name: row.name,
        parentId: row.parentId,
        updatedAt: row.updatedAt,
        essayCount: 0,
      ),
  ];

  Stream<List<Label>> watchLabels() =>
      db.select(db.essayLabels).watch().map(_readLabels);

  Future<List<Label>> labels() async =>
      _readLabels(await db.select(db.essayLabels).get());

  EssayEntry _entry(Essay item) => EssayEntry(
    id: item.id,
    date: item.date,
    wordCount: item.wordCount,
    title: item.title,
    content: item.content,
    imgs: jsonEncode(item.imgs),
    messages: jsonEncode(item.messages),
    mood: item.mood?.name,
    createdAt: item.createdAt,
    updatedAt: item.updatedAt!,
    labelsUpdatedAt: item.labelsUpdatedAt!,
  );

  Iterable<EssayLink> _links(Essay item) => [
    for (final (index, id) in item.labels.indexed)
      EssayLink(essayId: item.id, labelId: id, position: index),
  ];

  Future<void> _putEssay(Essay item, Essay? previous) => db.batch((batch) {
    batch.insertAllOnConflictUpdate(db.essayEntries, [_entry(item)]);
    if (!listEquals(item.labels, previous?.labels)) {
      batch.deleteWhere(db.essayLinks, (row) => row.essayId.equals(item.id));
      batch.insertAll(db.essayLinks, _links(item));
    }
  });

  EssayLabel _labelRow(Label label) => EssayLabel(
    id: label.id,
    name: label.name,
    parentId: label.parentId,
    updatedAt: label.updatedAt!,
  );

  bool _sameBody(Essay a, Essay b) =>
      a.title == b.title &&
      a.content == b.content &&
      a.mood == b.mood &&
      listEquals(a.imgs, b.imgs);

  Future<Essay> writeEssay({required Essay essay, Essay? original}) =>
      db.transaction(() async {
        final current = await this.essay(essay.id);
        if (original == null) {
          if (current != null ||
              await db.deletedAt('essay', 'essays', essay.id) != null) {
            throw StateError('随笔已存在或已删除，草稿已保留');
          }
        } else {
          if (current == null || !_sameBody(current, original)) {
            throw StateError('原随笔已修改或删除，草稿已保留');
          }
          final changedLabels = !listEquals(essay.labels, original.labels);
          if (changedLabels &&
              !listEquals(current.labels, original.labels) &&
              !listEquals(current.labels, essay.labels)) {
            throw StateError('原随笔的标签已修改，草稿已保留');
          }
          essay = current.copyWith(
            title: essay.title,
            content: essay.content,
            wordCount: current.content == essay.content
                ? current.wordCount
                : essay.wordCount,
            imgs: essay.imgs,
            labels: changedLabels ? essay.labels : current.labels,
            mood: essay.mood,
            clearMood: essay.mood == null,
          );
        }
        final saved = await _saveEssay(essay, current);
        await (db.delete(
          db.essayDrafts,
        )..where((row) => row.id.equals(essay.id))).go();
        return saved;
      });

  Future<Essay> _saveEssay(
    Essay item,
    Essay? previous, {
    DateTime? editedAt,
  }) async {
    final changedLabels = !listEquals(previous?.labels, item.labels);
    final changedContent =
        previous == null ||
        !_sameBody(item, previous) ||
        !listEquals(previous.messages, item.messages);
    if (!changedLabels && !changedContent) return previous;
    if (item.content.trim().isEmpty && item.imgs.isEmpty) {
      throw const FormatException('请填写正文或添加图片');
    }
    if (changedLabels) {
      final available = await (db.select(
        db.essayLabels,
      )..where((row) => row.id.isIn(item.labels))).get();
      if (item.labels.isEmpty ||
          item.labels.length > 4 ||
          item.labels.length != available.length) {
        throw const FormatException('请选择 1–4 个仍存在的标签');
      }
    }
    final contentStamp = changedContent
        ? editedAt ?? nextUserDataTime(previous?.updatedAt)
        : previous.updatedAt;
    final oldLabelStamp = previous?.labelsUpdatedAt;
    final saved = item.copyWith(
      updatedAt: contentStamp,
      createdAt: previous == null ? contentStamp : previous.createdAt,
      labelsUpdatedAt: changedLabels
          ? nextUserDataTime(oldLabelStamp)
          : oldLabelStamp,
    );
    await _putEssay(saved, previous);
    return saved;
  }

  Future<void> acceptSuggestions(
    Essay source, {
    String? title,
    required List<String> labelIds,
  }) => db.transaction(() async {
    final allLabels = await labels();
    final hidden = hiddenLabelIds(allLabels);
    final current = await essay(source.id);
    if (current == null ||
        current.content != source.content ||
        current.labels.any(hidden.contains)) {
      throw StateError('随笔已变更，请重新分析');
    }
    if (title != null &&
        current.title != source.title &&
        current.title != title) {
      throw StateError('随笔标题已变更，请重新分析');
    }
    final available = {
      for (final label in allLabels) label.id,
    }.difference(hidden);
    if (!available.containsAll(labelIds)) throw StateError('所选标签已不可用');
    final additions = labelIds.toSet().difference(current.labels.toSet());
    await _saveEssay(
      current.copyWith(title: title, labels: [...current.labels, ...additions]),
      current,
    );
  });

  Future<void> deleteEssay(Essay item) => db.transaction(() async {
    final current = await essay(item.id);
    if (current == null) return;
    await db.deleteVersion('essay', 'essays', item.id, current.updatedAt);
    await (db.delete(
      db.essayEntries,
    )..where((row) => row.id.equals(item.id))).go();
  });

  Future<void> retag(String essayId, String labelId) =>
      db.transaction(() async {
        final current = await essay(essayId);
        if (current == null) throw StateError('随笔已删除');
        final next = [...current.labels];
        if (next.contains(labelId)) {
          if (next.length <= 1) return;
          next.remove(labelId);
        } else {
          if (next.length >= 4) return;
          next.add(labelId);
        }
        await _saveEssay(current.copyWith(labels: next), current);
      });

  Future<void> appendMessage(String essayId, String content) =>
      db.transaction(() async {
        final current = await essay(essayId);
        if (current == null) throw StateError('随笔已删除');
        final text = content.trim();
        if (text.isEmpty) throw const FormatException('留言不能为空');
        final stamp = nextUserDataTime(current.updatedAt);
        final message = Message(
          timestamp: stamp,
          content: text,
          updatedAt: stamp,
        );
        await _saveEssay(
          current.copyWith(messages: [...current.messages, message]),
          current,
          editedAt: stamp,
        );
      });

  Future<void> editMessage(
    String essayId,
    int index,
    Message original,
    String content,
  ) => db.transaction(() async {
    final current = await essay(essayId);
    final text = content.trim();
    if (text.isEmpty) throw const FormatException('留言不能为空');
    if (current == null || index < 0 || index >= current.messages.length) {
      throw StateError('留言已不存在');
    }
    final message = current.messages[index];
    if (!message.timestamp.isAtSameMomentAs(original.timestamp) ||
        message.content != original.content ||
        message.updatedAt?.microsecondsSinceEpoch !=
            original.updatedAt?.microsecondsSinceEpoch) {
      throw StateError('留言已变更，请重新打开编辑');
    }
    if (text == message.content) return;
    final stamp = nextUserDataTime(current.updatedAt);
    final messages = [...current.messages];
    messages[index] = Message(
      timestamp: message.timestamp,
      content: text,
      updatedAt: stamp,
    );
    await _saveEssay(
      current.copyWith(messages: messages),
      current,
      editedAt: stamp,
    );
  });

  Future<void> saveLabel({
    Label? original,
    required String name,
    String? parentId,
  }) => db.transaction(() async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw const FormatException('标签名称不能为空');
    final all = {for (final label in await labels()) label.id: label};
    final current = all[original?.id];
    if (original != null &&
        (current == null ||
            current.name != original.name ||
            current.parentId != original.parentId)) {
      throw StateError('标签已变更，请重新打开编辑');
    }
    if (current?.isHiddenRoot ?? false) {
      throw const FormatException('隐藏标签不可修改');
    }
    if (all.values.any(
      (label) =>
          label.id != current?.id &&
          label.name == trimmed &&
          label.parentId == parentId,
    )) {
      throw const FormatException('同级标签已存在');
    }
    if (current != null &&
        current.name == trimmed &&
        current.parentId == parentId) {
      return;
    }
    final label = (current ?? Label.newOne(trimmed, parentId: parentId))
        .copyWith(
          name: trimmed,
          parentId: parentId,
          clearParent: parentId == null,
          updatedAt: nextUserDataTime(current?.updatedAt),
        );
    all[label.id] = label;
    validateLabelTree(all.values);
    await db.into(db.essayLabels).insertOnConflictUpdate(_labelRow(label));
  });

  Future<void> deleteLabel(Label label) => db.transaction(() async {
    final row = await (db.select(
      db.essayLabels,
    )..where((row) => row.id.equals(label.id))).getSingleOrNull();
    if (row == null) return;
    final current = _readLabels([row]).single;
    final used = await db.customSelect(r"""
      SELECT 1 FROM essay_links WHERE label_id = ?
      UNION ALL SELECT 1 FROM essay_labels WHERE parent_id = ?
      UNION ALL SELECT 1 FROM essay_drafts, json_each(essay, '$.labels') WHERE value = ?
      LIMIT 1
      """, variables: List.filled(3, Variable(label.id))).getSingleOrNull();
    if (current.isHiddenRoot || used != null) {
      throw const FormatException('只能删除未被随笔或草稿使用且没有子标签的普通标签');
    }
    await db.deleteVersion('essay', 'labels', current.id, current.updatedAt);
    await (db.delete(
      db.essayLabels,
    )..where((row) => row.id.equals(label.id))).go();
  });

  Future<Set<String>> syncImages(UserDataBatch sync) => db.transaction(
    () async {
      final table = db.essayEntries;
      final rows = await (db.selectOnly(
        table,
      )..addColumns([table.id, table.updatedAt, table.imgs])).get();
      return syncAttachmentPaths(
        {
          for (final row in rows)
            row.read(table.id)!: (
              updatedAt: DateTime.fromMicrosecondsSinceEpoch(
                row.read(table.updatedAt)!,
                isUtc: true,
              ),
              paths: (jsonDecode(row.read(table.imgs)!) as List).cast<String>(),
            ),
        },
        sync.rows('essays'),
        await db.deletionVersions(sync, 'essays'),
        (json) => (json['imgs'] as List).cast<String>(),
      );
    },
  );

  Future<void> syncData(
    UserDataBatch sync, {
    required String address,
  }) => db.transaction(() async {
    if (sync.affectedIds('labels').isNotEmpty) {
      await _syncLabels(sync);
    }

    final ids = sync.affectedIds('essays');
    if (ids.isNotEmpty) {
      final tombstones = await db.deletionVersions(sync, 'essays', save: true);
      final existing = {
        for (final item in _readEssays(await _essayQuery(ids).get()))
          item.id: item,
      };
      final removed = {
        for (final item in existing.values)
          if (isDeleted(item.updatedAt!, tombstones[item.id])) item.id,
      };
      final changes = <EssayEntry>[];
      final links = <String, Iterable<EssayLink>>{};
      for (final raw in sync.rows('essays').values) {
        final incoming = Essay.fromJson(raw);
        if (isDeleted(incoming.updatedAt!, tombstones[incoming.id])) continue;
        final old = existing[incoming.id];
        final incomingLabels = incoming.labelsUpdatedAt ?? incoming.updatedAt!;
        final tags = old?.labelsUpdatedAt?.isAfter(incomingLabels) == true
            ? old!
            : incoming;
        final body = old?.updatedAt?.isAfter(incoming.updatedAt!) == true
            ? old!
            : incoming;
        final merged = body.copyWith(
          date: incoming.date,
          createdAt: incoming.createdAt ?? old?.createdAt,
          labels: tags.labels,
          labelsUpdatedAt: tags.labelsUpdatedAt ?? tags.updatedAt,
        );
        if (merged.labels.toSet().length != merged.labels.length) {
          throw const FormatException('随笔标签重复');
        }
        removed.remove(merged.id);
        final entry = _entry(merged);
        if (old == null || entry != _entry(old)) changes.add(entry);
        if (!listEquals(merged.labels, old?.labels)) {
          links[merged.id] = _links(merged);
        }
      }
      await db.batch((batch) {
        if (removed.isNotEmpty) {
          batch.deleteWhere(db.essayEntries, (row) => row.id.isIn(removed));
        }
        batch.insertAllOnConflictUpdate(db.essayEntries, changes);
        if (links.isNotEmpty) {
          batch.deleteWhere(
            db.essayLinks,
            (row) => row.essayId.isIn(links.keys),
          );
          batch.insertAll(db.essayLinks, links.values.expand((items) => items));
        }
      });
    }
    await db.saveSyncCursor(address, 'essay', sync.cursor);
  });

  Future<void> _syncLabels(UserDataBatch sync) async {
    final tombstones = await db.deletionVersions(sync, 'labels', save: true);
    final old = {for (final label in await labels()) label.id: label};
    final merged = {...old};
    final removed = <String>{};
    for (final label in old.values) {
      if (!isDeleted(label.updatedAt!, tombstones[label.id])) continue;
      if (label.isHiddenRoot) throw const FormatException('隐藏标签不可删除');
      removed.add(label.id);
      merged.remove(label.id);
    }
    final changes = <EssayLabel>[];
    for (final raw in sync.rows('labels').values) {
      final incoming = Label.fromJson(raw);
      final previous = old[incoming.id];
      if (isDeleted(incoming.updatedAt!, tombstones[incoming.id]) ||
          previous?.updatedAt?.isAfter(incoming.updatedAt!) == true) {
        continue;
      }
      merged[incoming.id] = incoming;
      removed.remove(incoming.id);
      final row = _labelRow(incoming);
      if (previous == null || row != _labelRow(previous)) changes.add(row);
    }
    validateLabelTree(merged.values);
    await db.batch((batch) {
      if (removed.isNotEmpty) {
        batch.deleteWhere(db.essayLabels, (row) => row.id.isIn(removed));
      }
      batch.insertAllOnConflictUpdate(db.essayLabels, changes);
    });
  }

  Future<({Map<String, dynamic> data, Iterable<String> images})> snapshot() =>
      db.transaction(() async {
        final items = await essays();
        final allLabels = await labels();
        return (
          data: {
            'sync_version': 2,
            'essay_schema_version': essaySchemaVersion,
            'labels': countEssayLabels(
              visibleEssays(items, allLabels),
              allLabels,
            ).map((label) => label.toJson()).toList(),
            'essays': items.map((item) => item.toJson()).toList(),
            'tombstones': await db.tombstones('essay'),
          },
          images: items.expand((item) => item.imgs),
        );
      });
}
