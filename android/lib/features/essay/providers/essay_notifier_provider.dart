import 'dart:convert';

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
import 'package:torrid/features/essay/providers/setting_provider.dart';
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

  Map<String, YearSummary> _summaries(Iterable<Essay> essays) => {
    for (final year in essays.map((e) => e.year.toString()).toSet())
      year: YearSummary.fromEssays(year, essays),
  };

  Map<String, Label> _countLabels(
    Iterable<Essay> essays,
    Iterable<Label> labels,
  ) {
    final counts = <String, int>{};
    for (final essay in essays) {
      for (final id in essay.labels.toSet()) {
        counts[id] = (counts[id] ?? 0) + 1;
      }
    }
    return {
      for (final label in labels)
        label.id: label.copyWith(essayCount: counts[label.id] ?? 0),
    };
  }

  Future<void> refreshYear() =>
      replaceBoxes({state.summaryBox: _summaries(state.essayBox.values)});

  Future<void> refreshLabel() => state.labelBox.putAll(
    _countLabels(state.essayBox.values, state.labelBox.values),
  );

  // 同 ID 覆盖保存，失败时恢复各 Box，草稿由写作页保留。
  Future<void> _replaceEssays(
    Map<String, Essay> essays, {
    Map<String, String>? metadata,
  }) => replaceBoxes({
    if (metadata != null) userDataSyncBox: metadata,
    state.essayBox: essays,
    state.labelBox: _countLabels(essays.values, state.labelBox.values),
    state.summaryBox: _summaries(essays.values),
  });

  Future<void> writeEssay({required Essay essay}) => userDataWrite(() async {
    final keepAlive = ref.keepAlive();
    try {
      if (essay.labels.any((id) => !state.labelBox.containsKey(id))) {
        throw const FormatException('部分标签已不存在，请重新选择');
      }
      essay = essay.copyWith(
        updatedAt: nextUserDataTime(state.essayBox.get(essay.id)?.updatedAt),
      );
      await _replaceEssays({
        for (final item in state.essayBox.values) item.id: item,
        essay.id: essay,
      });
      ref.read(contentServerProvider.notifier).switchEssay(essay);
    } finally {
      keepAlive.close();
    }
  });

  Future<void> deleteEssay(Essay essay) => userDataWrite(
    () => _replaceEssays({
      for (final item in state.essayBox.values)
        if (item.id != essay.id) item.id: item,
    }, metadata: deletedUserData('essay', 'essays', essay.id, essay.updatedAt)),
  );

  Future<void> retag(String essayId, String labelId) async {
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
    await writeEssay(essay: essay.copyWith(labels: labels));
  }

  Future<void> appendMessage(String essayId, Message message) async {
    final essay = state.essayBox.get(essayId);
    if (essay == null) return;
    await writeEssay(
      essay: essay.copyWith(messages: [...essay.messages, message]),
    );
  }

  Future<void> saveLabel({
    Label? original,
    required String name,
    String? parentId,
  }) => userDataWrite(() async {
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
    await state.labelBox.put(
      label.id,
      label.copyWith(updatedAt: nextUserDataTime(original?.updatedAt)),
    );
  });

  Future<void> deleteLabel(Label label) => userDataWrite(() async {
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
  }) => userDataWrite(() async {
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
      userDataSyncBox: merged.metadata,
      state.summaryBox: _summaries(essays.values),
      state.labelBox: _countLabels(essays.values, completeLabels),
      state.essayBox: essays,
    });
  });

  Map<String, dynamic> snapshot() => {
    'labels': state.labelBox.values.map((l) => l.toJson()).toList(),
    'essays': state.essayBox.values.map((e) => e.toJson()).toList(),
  };

  Future<Map<String, dynamic>> packUp() => userDataWrite(() async {
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
        'tombstones': userDataTombstones('essay'),
      }),
    };
  });
}
