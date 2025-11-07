import 'package:hive/hive.dart';
import 'package:torrid/features/essay/models/essay.dart';

part 'year_summary.g.dart';

// ----随笔年度信息类
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

  factory YearSummary.fromJson(Map<String, dynamic> json) {
    return YearSummary(
      year: json['year'],
      essayCount: json['essayCount'] ?? 0,
      wordCount: json['totalWordCount'] ?? 0,
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
      'monthSummaries': monthSummaries.map((month) => month.toJson()).toList(),
    };
  }
}

// ----随笔月度信息类
@HiveType(typeId: 3)
class MonthSummary {
  @HiveField(0)
  final String month;

  @HiveField(1)
  final int essayCount;

  @HiveField(2)
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

  factory MonthSummary.fromJson(Map<String, dynamic> json) {
    return MonthSummary(
      month: json['month'],
      essayCount: json['essayCount'] ?? 0,
      wordCount: json['monthWordCount'] ?? 0,
    );
  }
  Map<String, dynamic> toJson() {
    return {"month": month, "essayCount": essayCount, "monthWordCount": wordCount};
  }
}
