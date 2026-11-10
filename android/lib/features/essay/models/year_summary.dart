import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:torrid/features/essay/models/essay.dart';

part 'year_summary.g.dart';

// 随笔年度信息类
@HiveType(typeId: 0)
@JsonSerializable(fieldRename: FieldRename.snake)
class YearSummary {
  @HiveField(0)
  final String year;

  @HiveField(1)
  @JsonKey(defaultValue: 0)
  final int essayCount;

  @HiveField(2)
  @JsonKey(defaultValue: 0)
  final int wordCount;

  @HiveField(3)
  final List<MonthSummary> monthSummaries;

  YearSummary({
    required this.year,
    this.essayCount = 0,
    this.wordCount = 0,
    List<MonthSummary>? monthSummaries,
  }) : monthSummaries = monthSummaries ?? [];

  /// 单年按月汇总，year=-1 时按年汇总；统计始终从随笔重算。
  factory YearSummary.fromEssays(String year, Iterable<Essay> essays) {
    final counts = <int, int>{};
    final words = <int, int>{};
    var essayCount = 0;
    var wordCount = 0;
    for (final essay in essays) {
      if (year != '-1' && essay.year.toString() != year) continue;
      final period = year == '-1' ? essay.year : essay.month;
      counts[period] = (counts[period] ?? 0) + 1;
      words[period] = (words[period] ?? 0) + essay.totalWordCount;
      essayCount++;
      wordCount += essay.totalWordCount;
    }
    return YearSummary(
      year: year,
      essayCount: essayCount,
      wordCount: wordCount,
      monthSummaries: [
        for (final period in counts.keys.toList()..sort())
          MonthSummary(
            month: '$period',
            essayCount: counts[period]!,
            wordCount: words[period]!,
          ),
      ],
    );
  }

  static Map<String, YearSummary> groupByYear(Iterable<Essay> essays) {
    final groups = <String, List<Essay>>{};
    for (final essay in essays) {
      groups.putIfAbsent(essay.year.toString(), () => []).add(essay);
    }
    return {
      for (final group in groups.entries)
        group.key: YearSummary.fromEssays(group.key, group.value),
    };
  }

  // (反)序列化
  factory YearSummary.fromJson(Map<String, dynamic> json) =>
      _$YearSummaryFromJson(json);
  Map<String, dynamic> toJson() => _$YearSummaryToJson(this);
}

// 随笔月度信息类
@HiveType(typeId: 3)
@JsonSerializable(fieldRename: FieldRename.snake)
class MonthSummary {
  @HiveField(0)
  final String month;

  @HiveField(1)
  @JsonKey(defaultValue: 0)
  final int essayCount;

  @HiveField(2)
  @JsonKey(defaultValue: 0)
  final int wordCount;

  MonthSummary({required this.month, this.essayCount = 0, this.wordCount = 0});

  // (反)序列化
  factory MonthSummary.fromJson(Map<String, dynamic> json) =>
      _$MonthSummaryFromJson(json);
  Map<String, dynamic> toJson() => _$MonthSummaryToJson(this);
}
