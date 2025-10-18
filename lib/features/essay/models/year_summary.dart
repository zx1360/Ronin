import 'package:hive/hive.dart';
import 'package:torrid/features/essay/models/essay.dart';

part 'year_summary.g.dart';

// 随笔年度信息类
@HiveType(typeId: 0)
class YearSummary {
  @HiveField(0)
  final String year;

  @HiveField(1)
  final int essayCount;

  @HiveField(2)
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

  YearSummary append({
    required Essay essay,
  }) {
    return YearSummary(
      year: year,
      essayCount: essayCount+1,
      wordCount: wordCount+essay.wordCount,
      monthSummaries: monthSummaries,
    );
  }

  factory YearSummary.fromJson(Map<String, dynamic> json) {
    return YearSummary(
      year: json['year'],
      essayCount: json['essayCount']??0,
      wordCount: json['wordCount']??0,
      monthSummaries: json.containsKey('monthSummaries')
          ? (json['monthSummaries'] as List)
                .map((item) => MonthSummary.fromJson(item))
                .toList()
          : [],
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'year': year,
      'essayCount': essayCount,
      // TODO: 数据格式统一后, 改用这个字段名
      // 'totalWordCount': wordCount,
      // 'months': monthSummaries.map((month) => month.toJson()).toList(),
      'wordCount': wordCount,
      'monthSummaries': monthSummaries.map((month) => month.toJson()).toList(),
    };
  }
}

// 随笔月度信息类
@HiveType(typeId: 3)
class MonthSummary {
  @HiveField(0)
  final String month;

  @HiveField(1)
  final int essayCount;

  @HiveField(2)
  final int wordCount;

  MonthSummary({required this.month, this.essayCount = 0, this.wordCount = 0});

  MonthSummary copyWith({
    String? month,
    int? essayCount,
    int? wordCount,
  }) {
    return MonthSummary(
      month: month ?? this.month,
      essayCount: essayCount ?? this.essayCount,
      wordCount: wordCount ?? this.wordCount,
    );
  }

  MonthSummary append({
    required Essay essay,
  }) {
    return MonthSummary(
      month: month,
      essayCount: essayCount+1,
      wordCount: wordCount+essay.wordCount,
    );
  }

  factory MonthSummary.fromJson(Map<String, dynamic> json) {
    return MonthSummary(
      month: json['month'],
      essayCount: json['essayCount']??0,
      wordCount: json['wordCount']??0,
    );
  }
  Map<String, dynamic> toJson() {
    return {"month": month, "essayCount": essayCount, "wordCount": wordCount};
  }
}
