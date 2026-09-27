// ⚠️ Hive 按字段序号序列化：新增字段只能**追加**在现有 @HiveField 之后，
//    既不能插入也不能重排；@HiveType(typeId) 与既有 @HiveField 编号同样不可改动。
//    否则会破坏所有已存在的本地数据库（读旧数据时字段错位）。
import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:torrid/core/api/user_data_sync.dart';
import 'package:torrid/features/essay/models/essay.dart';

part 'year_summary.g.dart';

// 随笔年度信息类
@HiveType(typeId: 0)
@JsonSerializable(fieldRename: FieldRename.snake)
class YearSummary implements SyncRow {
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

  // ↓↓↓ 同步元数据：只允许追加（见文件头注释） ↓↓↓

  /// 服务端的年度汇总表没有 created_at，这里允许为 null。
  @HiveField(4)
  @JsonKey(fromJson: syncTimeFromJson, toJson: syncTimeToJson)
  final DateTime? createdAt;

  @HiveField(5)
  @JsonKey(fromJson: syncTimeFromJson, toJson: syncTimeToJson)
  final DateTime? updatedAt;

  /// 墓碑：非空表示已删除，仅用于把删除动作同步出去，UI 必须过滤。
  @HiveField(6)
  @JsonKey(fromJson: syncTimeFromJson, toJson: syncTimeToJson)
  final DateTime? deletedAt;

  YearSummary({
    required this.year,
    this.essayCount = 0,
    this.wordCount = 0,
    List<MonthSummary>? monthSummaries,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  }) : monthSummaries = monthSummaries ?? [];

  YearSummary copyWith({
    String? year,
    int? essayCount,
    int? wordCount,
    List<MonthSummary>? monthSummaries,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDeleted = false,
  }) {
    return YearSummary(
      year: year ?? this.year,
      essayCount: essayCount ?? this.essayCount,
      wordCount: wordCount ?? this.wordCount,
      monthSummaries: monthSummaries ?? this.monthSummaries,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeleted ? null : (deletedAt ?? this.deletedAt),
    );
  }

  /// 从指定年份的 essays 列表计算生成 YearSummary
  /// 用于刷新/重建年度统计信息
  ///
  /// 刻意不带同步元数据：这是**派生**数据，调用方需自行决定是新建
  /// （`touchSyncTimes`）还是保留既有行的 `created_at`/`updated_at`
  /// —— 派生重算不应该凭时间戳压过另一端的真实编辑。
  factory YearSummary.fromEssays(String year, Iterable<Essay> essays) {
    final essaysInYear = essays.where((e) => e.date.year.toString() == year);
    final monthSummaries = <MonthSummary>[];
    for (int month = 1; month <= 12; month++) {
      final summary = MonthSummary.fromEssays(month, essaysInYear);
      if (summary.essayCount > 0) {
        monthSummaries.add(summary);
      }
    }
    return YearSummary(
      year: year,
      essayCount: essaysInYear.length,
      wordCount: essaysInYear.fold(0, (sum, e) => sum + e.wordCount),
      monthSummaries: monthSummaries,
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
      // 派生重算保留既有同步元数据，避免本地重算"抢"掉其它设备的编辑
      createdAt: createdAt,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
    );
  }

  // SyncRow：年度汇总在两端都以 year 为键。
  @override
  String get syncStorageKey => year;

  @override
  String get syncMatchKey => year;

  @override
  DateTime? get syncCreatedAt => createdAt;

  @override
  DateTime? get syncUpdatedAt => updatedAt;

  @override
  DateTime? get syncDeletedAt => deletedAt;

  // (反)序列化
  factory YearSummary.fromJson(Map<String, dynamic> json) =>
      _$YearSummaryFromJson(json);
  Map<String, dynamic> toJson() => _$YearSummaryToJson(this);
}

// 随笔月度信息类（嵌套在年度汇总里，不是独立同步行，故不带同步元数据）
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

  /// 从指定月份的 essays 列表计算生成 MonthSummary
  factory MonthSummary.fromEssays(int month, Iterable<Essay> essays) {
    final essaysInMonth = essays.where((e) => e.date.month == month);
    return MonthSummary(
      month: month.toString(),
      essayCount: essaysInMonth.length,
      wordCount: essaysInMonth.fold(0, (sum, e) => sum + e.wordCount),
    );
  }

  // (反)序列化
  factory MonthSummary.fromJson(Map<String, dynamic> json) =>
      _$MonthSummaryFromJson(json);
  Map<String, dynamic> toJson() => _$MonthSummaryToJson(this);
}
