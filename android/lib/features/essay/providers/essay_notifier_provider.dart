import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/core/models/message.dart';
import 'package:torrid/core/services/storage/box_replace.dart';
import 'package:torrid/core/services/storage/user_data_sync.dart';
import 'package:torrid/features/essay/models/essay.dart';
import 'package:torrid/features/essay/models/label.dart';
import 'package:torrid/features/essay/models/label_tree.dart';
import 'package:torrid/features/essay/models/year_summary.dart';
import 'package:torrid/features/essay/providers/box_provider.dart';
import 'package:torrid/features/essay/services/essay_contract.dart';
import 'package:torrid/features/essay/services/essay_draft_store.dart';

part 'essay_notifier_provider.g.dart';

class EssayRepository {
  final Box<YearSummary> summaryBox;
  final Box<Essay> essayBox;
  final Box<Label> labelBox;

  const EssayRepository({
    required this.summaryBox,
    required this.essayBox,
    required this.labelBox,
  });
}

@riverpod
class EssayService extends _$EssayService {
  @override
  EssayRepository build() => EssayRepository(
    summaryBox: ref.read(summaryBoxProvider),
    essayBox: ref.read(essayBoxProvider),
    labelBox: ref.read(labelBoxProvider),
  );

  Map<Box<dynamic>, Map<dynamic, dynamic>> _statistics(
    Iterable<Essay> essays,
    Iterable<Label> labels,
  ) {
    final visible = visibleEssays(essays, labels);
    return {
      state.labelBox: {
        for (final label in countEssayLabels(visible, labels)) label.id: label,
      },
      state.summaryBox: YearSummary.groupByYear(visible),
    };
  }

  Future<void> refreshStatistics() => _write(
    () =>
        replaceBoxes(_statistics(state.essayBox.values, state.labelBox.values)),
  );

  Future<void> _replaceEssays(
    Map<String, Essay> essays, {
    Map<String, String>? metadata,
  }) => replaceBoxes({
    if (metadata != null) userDataSyncBox: metadata,
    state.essayBox: essays,
    ..._statistics(essays.values, state.labelBox.values),
  });

  Future<T> _write<T>(Future<T> Function() action) {
    final keepAlive = ref.keepAlive();
    return userDataWrite(action).whenComplete(keepAlive.close);
  }

  bool _sameBody(Essay a, Essay b) =>
      a.title == b.title &&
      a.content == b.content &&
      a.mood == b.mood &&
      listEquals(a.imgs, b.imgs);

  Future<Essay> writeEssay({required Essay essay, Essay? original}) =>
      _write(() async {
        final current = state.essayBox.get(essay.id);
        if (original == null) {
          if (current != null) throw StateError('随笔已存在，草稿已保留');
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
        return _saveEssay(essay, current);
      });

  Future<Essay> _saveEssay(
    Essay essay,
    Essay? previous, {
    DateTime? editedAt,
  }) async {
    final changedLabels = !listEquals(previous?.labels, essay.labels);
    final changedContent =
        previous == null ||
        !_sameBody(essay, previous) ||
        !listEquals(previous.messages, essay.messages);
    if (!changedLabels && !changedContent) return previous;
    if (changedLabels &&
        (essay.labels.isEmpty ||
            essay.labels.length > 4 ||
            essay.labels.any((id) => !state.labelBox.containsKey(id)))) {
      throw const FormatException('请选择 1–4 个仍存在的标签');
    }
    final contentStamp = changedContent
        ? editedAt ?? nextUserDataTime(previous?.updatedAt)
        : previous.updatedAt;
    final oldLabelStamp = previous?.labelsUpdatedAt ?? previous?.updatedAt;
    essay = essay.copyWith(
      updatedAt: contentStamp,
      createdAt: previous == null ? contentStamp : previous.createdAt,
      labelsUpdatedAt: changedLabels
          ? nextUserDataTime(oldLabelStamp)
          : oldLabelStamp,
    );
    await _replaceEssays({
      for (final item in state.essayBox.values) item.id: item,
      essay.id: essay,
    });
    return essay;
  }

  Essay _suggestionTarget(Essay source, Set<String> hidden) {
    final essay = state.essayBox.get(source.id);
    if (essay == null ||
        essay.content != source.content ||
        essay.labels.any(hidden.contains)) {
      throw StateError('随笔已变更，请重新分析');
    }
    return essay;
  }

  Future<void> acceptSuggestions(
    Essay source, {
    String? title,
    required List<String> labelIds,
  }) => _write(() async {
    final hidden = hiddenLabelIds(state.labelBox.values);
    final essay = _suggestionTarget(source, hidden);
    if (title != null && essay.title != source.title && essay.title != title) {
      throw StateError('随笔标题已变更，请重新分析');
    }
    if (labelIds.any(
      (id) => !state.labelBox.containsKey(id) || hidden.contains(id),
    )) {
      throw StateError('所选标签已不可用');
    }
    final additions = labelIds.toSet().difference(essay.labels.toSet());
    final labels = [...essay.labels, ...additions];
    if (additions.isNotEmpty && labels.length > 4) {
      throw StateError('随笔最多可有 4 个标签');
    }
    await _saveEssay(essay.copyWith(title: title, labels: labels), essay);
  });

  Future<void> deleteEssay(Essay essay) => _write(() async {
    final current = state.essayBox.get(essay.id);
    if (current == null) return;
    await _replaceEssays(
      {
        for (final item in state.essayBox.values)
          if (item.id != essay.id) item.id: item,
      },
      metadata: deletedUserData('essay', 'essays', essay.id, current.updatedAt),
    );
  });

  Future<void> retag(String essayId, String labelId) => _write(() async {
    final essay = state.essayBox.get(essayId);
    if (essay == null || !state.labelBox.containsKey(labelId)) return;
    final labels = List<String>.of(essay.labels);
    if (labels.contains(labelId)) {
      if (labels.length <= 1) return;
      labels.remove(labelId);
    } else {
      if (labels.length >= 4) return;
      labels.add(labelId);
    }
    await _saveEssay(essay.copyWith(labels: labels), essay);
  });

  Future<void> appendMessage(String essayId, String content) =>
      _write(() async {
        final essay = state.essayBox.get(essayId);
        if (essay == null) throw StateError('随笔已删除');
        final text = content.trim();
        if (text.isEmpty) throw const FormatException('留言不能为空');
        final stamp = nextUserDataTime(essay.updatedAt);
        final message = Message(
          timestamp: DateTime.now(),
          content: text,
          updatedAt: stamp,
        );
        await _saveEssay(
          essay.copyWith(messages: [...essay.messages, message]),
          essay,
          editedAt: stamp,
        );
      });

  Future<void> editMessage(
    String essayId,
    int index,
    Message original,
    String content,
  ) => _write(() async {
    final essay = state.essayBox.get(essayId);
    final text = content.trim();
    if (text.isEmpty) throw const FormatException('留言不能为空');
    if (essay == null || index < 0 || index >= essay.messages.length) {
      throw StateError('留言已不存在');
    }
    final current = essay.messages[index];
    if (!current.timestamp.isAtSameMomentAs(original.timestamp) ||
        current.content != original.content ||
        current.updatedAt?.millisecondsSinceEpoch !=
            original.updatedAt?.millisecondsSinceEpoch) {
      throw StateError('留言已变更，请重新打开编辑');
    }
    if (text == current.content) return;
    final stamp = nextUserDataTime(essay.updatedAt);
    final messages = List.of(essay.messages);
    messages[index] = Message(
      timestamp: current.timestamp,
      content: text,
      updatedAt: stamp,
    );
    await _saveEssay(
      essay.copyWith(messages: messages),
      essay,
      editedAt: stamp,
    );
  });

  Future<void> saveLabel({
    Label? original,
    required String name,
    String? parentId,
  }) => _write(() async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw const FormatException('标签名称不能为空');
    if (original?.isHiddenRoot ?? false) {
      throw const FormatException('隐藏标签不可修改');
    }
    if (state.labelBox.values.any(
      (l) =>
          l.id != original?.id && l.name == trimmed && l.parentId == parentId,
    )) {
      throw const FormatException('同级标签已存在');
    }
    final label =
        original?.copyWith(
          name: trimmed,
          parentId: parentId,
          clearParent: parentId == null,
        ) ??
        Label.newOne(trimmed, parentId: parentId);
    final labels = {
      for (final item in state.labelBox.values) item.id: item,
      label.id: label,
    };
    validateLabelTree(labels.values);
    labels[label.id] = label.copyWith(
      updatedAt: nextUserDataTime(original?.updatedAt),
    );
    await replaceBoxes(_statistics(state.essayBox.values, labels.values));
  });

  Future<void> deleteLabel(Label label) => _write(() async {
    if (label.isHiddenRoot ||
        state.labelBox.values.any((l) => l.parentId == label.id) ||
        state.essayBox.values.any((e) => e.labels.contains(label.id)) ||
        ref
            .read(essayDraftStoreProvider)
            .all()
            .any((d) => d.essay.labels.contains(label.id))) {
      throw const FormatException('只能删除未被随笔或草稿使用且没有子标签的普通标签');
    }
    await replaceBoxes({
      state.labelBox: state.labelBox.toMap()..remove(label.id),
      userDataSyncBox: deletedUserData(
        'essay',
        'labels',
        label.id,
        label.updatedAt,
      ),
    });
  });

  Future<void> syncData(
    dynamic incoming, {
    String? cursorKey,
  }) => _write(() async {
    final merged = mergeUserData(
      'essay',
      snapshot(),
      Map<String, dynamic>.from(incoming as Map),
    );
    final json = merged.data;
    // 连同旧汇总一起解析校验，统计以实际随笔重建。
    for (final raw in json['year_summaries'] as List) {
      YearSummary.fromJson(raw as Map<String, dynamic>);
    }
    final labels = <String, Label>{};
    for (final raw in json['labels'] as List) {
      final label = Label.fromJson(raw as Map<String, dynamic>);
      if (labels.containsKey(label.id)) throw const FormatException('标签 ID 重复');
      labels[label.id] = label;
    }
    final completeLabels = ensureHiddenLabel(labels.values);
    validateLabelTree(completeLabels);
    final essays = <String, Essay>{};
    for (final raw in json['essays'] as List) {
      final essay = Essay.fromJson(raw as Map<String, dynamic>);
      if (essay.id.isEmpty || essays.containsKey(essay.id)) {
        throw const FormatException('随笔 ID 无效或重复');
      }
      if (essay.labels.any((id) => !completeLabels.any((l) => l.id == id))) {
        throw const FormatException('随笔引用了不存在的标签');
      }
      essays[essay.id] = essay;
    }
    if (cursorKey != null) {
      merged.metadata[cursorKey] = incoming['cursor'].toString();
    }
    await replaceBoxes({
      ..._statistics(essays.values, completeLabels),
      state.essayBox: essays,
      userDataSyncBox: merged.metadata,
    });
  });

  Map<String, dynamic> snapshot() => {
    'labels': state.labelBox.values.map((l) => l.toJson()).toList(),
    'essays': state.essayBox.values.map((e) => e.toJson()).toList(),
  };

  Future<Map<String, dynamic>> packUp() => _write(() async {
    for (final label in state.labelBox.values.toList()) {
      if (label.updatedAt == null) {
        await state.labelBox.put(
          label.id,
          label.copyWith(updatedAt: nextUserDataTime()),
        );
      }
    }
    for (final essay in state.essayBox.values.toList()) {
      if (essay.updatedAt == null) {
        await state.essayBox.put(
          essay.id,
          essay.copyWith(updatedAt: nextUserDataTime()),
        );
      }
    }
    return {
      'jsonData': jsonEncode({
        ...snapshot(),
        'sync_version': 2,
        'essay_schema_version': essaySchemaVersion,
        'tombstones': userDataTombstones('essay'),
      }),
    };
  });
}
