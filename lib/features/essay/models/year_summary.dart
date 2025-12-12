import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:torrid/features/essay/models/essay.dart';

part 'year_summary.g.dart';

// ----随笔年度信息类
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
  List<MonthSummary> monthSummaries;

  YearSummary({
    required this.year,
    this.essayCount = 0,
    this.wordCount = 0,
    List<MonthSummary>? monthSummaries,
  }) : monthSummaries = monthSummaries ?? [];

  YearSummary copyWith({
    String? year,
    int? essayCount,
    int? wordCount,
    List<MonthSummary>? monthSummaries,
  }) {
    return YearSummary(
      year: year ?? this.year,
      essayCount: essayCount ?? this.essayCount,
      wordCount: wordCount ?? this.wordCount,
      monthSummaries: monthSummaries ?? this.monthSummaries,
    );
  }

  // 增/删随笔时. 更新信息.
  YearSummary edit({required Essay essay, required bool isAppend}) {
    int flag = isAppend ? 1 : -1;
    final monthSummaries = List.of(this.monthSummaries);
    final currentMonthSummaries = monthSummaries
        .where((m) => m.month == essay.date.month.toString())
        .toList();

    late final MonthSummary monthSummary;
    if (currentMonthSummaries.isEmpty) {
      monthSummary = MonthSummary(month: essay.date.month.toString());
    } else {
      monthSummary = currentMonthSummaries.first;
      monthSummaries.remove(monthSummary);
    }

    return YearSummary(
      year: year,
      essayCount: essayCount + 1 * flag,
      wordCount: wordCount + essay.wordCount * flag,
      monthSummaries: monthSummaries
        ..add(monthSummary.edit(essay: essay, isAppend: isAppend)),
    );
  }

  // (反)序列化
  factory YearSummary.fromJson(Map<String, dynamic> json) =>
      _$YearSummaryFromJson(json);
  Map<String, dynamic> toJson() => _$YearSummaryToJson(this);
}

// ----随笔月度信息类
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

  MonthSummary copyWith({String? month, int? essayCount, int? wordCount}) {
    return MonthSummary(
      month: month ?? this.month,
      essayCount: essayCount ?? this.essayCount,
      wordCount: wordCount ?? this.wordCount,
    );
  }

  MonthSummary edit({required Essay essay, required bool isAppend}) {
    int flag = isAppend ? 1 : -1;
    return MonthSummary(
      month: month,
      essayCount: essayCount + flag,
      wordCount: wordCount + essay.wordCount * flag,
    );
  }

  // (反)序列化
  factory MonthSummary.fromJson(Map<String, dynamic> json) =>
      _$MonthSummaryFromJson(json);
  Map<String, dynamic> toJson() => _$MonthSummaryToJson(this);
}
