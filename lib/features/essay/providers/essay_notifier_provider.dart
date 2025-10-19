import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/essay/models/essay.dart';
import 'package:torrid/features/essay/models/label.dart';
import 'package:torrid/features/essay/models/year_summary.dart';
import 'package:torrid/features/essay/providers/box_provider.dart';
import 'package:torrid/services/io/io_service.dart';
import 'package:torrid/shared/models/message.dart';

part 'essay_notifier_provider.g.dart';

// ----浏览设置类----
class BrowseSettings {
  final SortType sortType;
  final List<String> selectedLabels;

  BrowseSettings({
    this.sortType = SortType.descending,
    this.selectedLabels = const [],
  });

  BrowseSettings copyWith({SortType? sortType, List<String>? selectedLabels}) {
    return BrowseSettings(
      sortType: sortType ?? this.sortType,
      selectedLabels: selectedLabels ?? this.selectedLabels,
    );
  }
}

enum SortType { ascending, descending, random }

// 浏览设置提供者
@riverpod
class BrowseManager extends _$BrowseManager {
  @override
  BrowseSettings build() {
    return BrowseSettings();
  }

  void setSortType(SortType sortType) {
    state = state.copyWith(sortType: sortType);
  }

  void toggleLabel(String labelId) {
    final selectedLabels = List<String>.from(state.selectedLabels);
    if (selectedLabels.contains(labelId)) {
      selectedLabels.remove(labelId);
    } else {
      selectedLabels.add(labelId);
    }
    state = state.copyWith(selectedLabels: selectedLabels);
  }

  void clearFilters() {
    state = BrowseSettings();
  }
}

// ----方便呈现的当前浏览essay----
@riverpod
class ContentServer extends _$ContentServer {
  @override
  Essay? build() {
    return null;
  }

  void switchEssay(Essay essay) {
    state = essay.copyWith();
  }
}

// ----修改执行者----
class Cashier {
  final Box<YearSummary> summaryBox;
  final Box<Essay> essayBox;
  final Box<Label> labelBox;

  Cashier({
    required this.summaryBox,
    required this.essayBox,
    required this.labelBox,
  });
}

@riverpod
class EssayService extends _$EssayService {
  @override
  Cashier build() {
    return Cashier(
      summaryBox: ref.read(summaryBoxProvider),
      essayBox: ref.read(essayBoxProvider),
      labelBox: ref.read(labelBoxProvider),
    );
  }

  // 刷新summary的信息
  Future<void> refreshYear() async {}

  // 刷新labels信息.
  Future<void> refreshLabel() async {}

  // 写随笔 $$$$: 对随笔的删改在northstar中实现吧, torrid就纯净简单的呈现和产生数据.
  Future<void> writeEssay(Essay essay) async {
    state.essayBox.put(essay.id, essay);
    for (final labelId in essay.labels) {
      final label_ = state.labelBox.get(labelId)!;
      state.labelBox.put(
        labelId,
        label_.copyWith(essayCount: label_.essayCount + 1),
      );
    }
    // 更新summary.
    final summaryBox = state.summaryBox;
    final yearSummary = summaryBox.get(essay.date.year.toString())!;
    summaryBox.put(
      yearSummary.year,
      yearSummary.edit(essay: essay, isAppend: true),
    );
  }

  // 对某篇随笔的标签重选
  Future<void> retag(String essayId, String labelId) async {
    final originalEssay = state.essayBox.get(essayId)!;

    final originalLabel = state.labelBox.get(labelId)!;
    if (originalEssay.labels.contains(labelId)) {
      if (originalEssay.labels.length <= 1) return;
      await state.essayBox.put(
        originalEssay.id,
        originalEssay.copyWith(labels: originalEssay.labels..remove(labelId)),
      );
      await state.labelBox.put(
        labelId,
        originalLabel.copyWith(essayCount: originalLabel.essayCount - 1),
      );
    } else {
      await state.essayBox.put(
        originalEssay.id,
        originalEssay.copyWith(labels: originalEssay.labels..add(labelId)),
      );
      await state.labelBox.put(
        labelId,
        originalLabel.copyWith(essayCount: originalLabel.essayCount + 1),
      );
    }

    ref
        .read(contentServerProvider.notifier)
        .switchEssay(state.essayBox.get(essayId)!);
    await refreshLabel();
  }

  // 对某篇随笔追加留言
  Future<void> appendMessage(String essayId, Message message) async {
    final originalEssay = state.essayBox.get(essayId);
    final essay = originalEssay!.copyWith(
      messages: originalEssay.messages..add(message),
    );
    await state.essayBox.put(essay.id, essay);
  }

  // 新增标签名
  Future<void> addLabel(String name) async {
    await deleteZeroLabels();
    final label = Label.newOne(name);
    await state.labelBox.put(label.id, label);
  }

  // 删除所有对应随笔数为0的标签.
  Future<void> deleteZeroLabels() async {
    // 删除所有对应随笔数为0的标签.
    await state.labelBox.deleteAll(
      state.labelBox.values
          .where((label) => label.essayCount == 0)
          .map((l) => l.id),
    );
  }

  // 数据同步/备份.
  // TODO: 数据格式完全一样之后删去相关逻辑.
  Future<void> syncData(dynamic json) async {
    await state.summaryBox.clear();
    await state.labelBox.clear();
    await state.essayBox.clear();
    // 年度(月度)信息
    for (Map<String, dynamic> yearSummary in (json['year_summaries'] as List)) {
      await state.summaryBox.put(
        yearSummary['year'],
        YearSummary.fromJson(yearSummary),
      );
      final Map<String, String> labelIdMap = {};

      // 标签信息
      for (Map<String, dynamic> label in (json['labels'] as List)) {
        final label_ = Label.fromJson(label);
        labelIdMap.addAll({label['id']: label_.id});
        await state.labelBox.put(label_.id, label_);
      }
      // 随笔内容
      for (Map<String, dynamic> essay in (json['essays'] as List)) {
        var essay_ = Essay.fromJson(essay);
        essay_ = essay_.copyWith(
          labels: essay_.labels.map((label) => labelIdMap[label]!).toList(),
        );
        await state.essayBox.put(essay_.id, essay_);
      }
      // 一并保存图片文件
      List<String> urls = [];
      state.essayBox.values
          .where((essay) => essay.imgs.isNotEmpty)
          .toList()
          .forEach((essay) {
            for (var img in essay.imgs) {
              urls.add(img);
            }
          });
      if (urls.isNotEmpty) {
        await IoService.saveFromRelativeUrls(urls, "img_storage/essay");
      }
    }
  }

  // 打包essay本地数据
  Map<String, dynamic> packUp() {
    final yearSummaries = (state.summaryBox.values.toList()
      ..sort((a, b) => b.year.compareTo(a.year)))
      .map((item) => item.toJson()).toList();
    final labels = (state.labelBox.values.toList()
        ..sort((a, b) => b.essayCount.compareTo(a.essayCount)))
        .map((item) => item.toJson())
        .toList();
    final essays = (state.essayBox.values.toList()
        ..sort((a, b) => b.date.compareTo(a.date)))
        .map((item) => item.toJson())
        .toList();
    return {
      "jsonData": jsonEncode({
        "year_summaries": yearSummaries,
        "labels": labels,
        "essays": essays,
      }),
    };
  }

  // 上传相关图片
  List<String> getImgsPath() {
    List<String> urls = [];
    for (var essay in state.essayBox.values) {
      for (var img in essay.imgs) {
        final relativePath = img.startsWith("/")
            ? img.replaceFirst("/", "")
            : img;
        urls.add(relativePath);
      }
    }
    return urls;
  }
}
