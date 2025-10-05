import 'package:hive/hive.dart';

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
      'totalWordCount': wordCount,
      'months': monthSummaries.map((month) => month.toJson()).toList(),
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
