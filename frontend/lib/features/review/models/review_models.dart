/// 近期回顾的 wire 模型（`/API/ai/review*`）。
///
/// 这些类型原先由后端契约生成，但它们只有"近期回顾"一个消费者，且需要容忍字段缺失
/// （后端加字段、模型降级时接口仍返回部分内容），因此在端上手写：
/// 只做容错解析，不引入代码生成。
library;

class ReviewPreset {
  const ReviewPreset({
    required this.id,
    required this.name,
    required this.tone,
    required this.role,
    required this.isDefault,
  });

  factory ReviewPreset.fromJson(Map<String, dynamic> json) {
    return ReviewPreset(
      id: _asString(json['id']),
      name: _asString(json['name']),
      tone: _asString(json['tone']),
      role: _asString(json['role']),
      isDefault: _asBool(json['is_default']),
    );
  }

  final String id;
  final String name;

  /// 语气与角色，均由用户在预设对话框里编辑。
  final String tone;
  final String role;
  final bool isDefault;
}

/// 一次回顾的结果：统计由后端算出，叙述由本地模型写入。
class ReviewResult {
  const ReviewResult({
    required this.stats,
    required this.narrative,
    this.model,
    required this.presetId,
    this.preset,
    required this.cached,
    this.createdAt,
    this.notice,
  });

  factory ReviewResult.fromJson(Map<String, dynamic> json) {
    return ReviewResult(
      stats: Stats.fromJson(_asMap(json['stats'])),
      narrative: _asString(json['narrative']),
      model: _asStringOrNull(json['model']),
      presetId: _asString(json['preset_id']),
      preset: _asStringOrNull(json['preset_name']),
      cached: _asBool(json['cached']),
      createdAt: _asStringOrNull(json['created_at']),
      notice: _asStringOrNull(json['notice']),
    );
  }

  final Stats stats;
  final String narrative;

  /// 生成叙述的模型；模型不可用时为空，此时 [notice] 说明原因。
  final String? model;
  final String presetId;
  final String? preset;
  final bool cached;
  final String? createdAt;
  final String? notice;
}

class Stats {
  const Stats({
    required this.from,
    required this.to,
    required this.days,
    required this.facts,
    required this.booklet,
    required this.essay,
  });

  factory Stats.fromJson(Map<String, dynamic> json) {
    return Stats(
      from: _asString(json['from']),
      to: _asString(json['to']),
      days: _asInt(json['days']),
      facts: _asStringList(json['facts']),
      booklet: BookletStats.fromJson(_asMap(json['booklet'])),
      essay: EssayStats.fromJson(_asMap(json['essay'])),
    );
  }

  final String from;
  final String to;
  final int days;

  /// 可直接展示的事实句，由后端从数据库算出。
  final List<String> facts;
  final BookletStats booklet;
  final EssayStats essay;
}

class BookletStats {
  const BookletStats({
    required this.activeStyles,
    required this.totalRecords,
    required this.checkInDays,
    required this.currentStreak,
    required this.longestStreak,
    required this.completionRate,
    required this.moodCounts,
    required this.topTasks,
  });

  factory BookletStats.fromJson(Map<String, dynamic> json) {
    return BookletStats(
      activeStyles: _asInt(json['active_styles']),
      totalRecords: _asInt(json['total_records']),
      checkInDays: _asInt(json['check_in_days']),
      currentStreak: _asInt(json['current_streak']),
      longestStreak: _asInt(json['longest_streak']),
      completionRate: _asDouble(json['completion_rate']),
      moodCounts: _asIntMap(json['mood_counts']),
      topTasks: [
        for (final item in _asList(json['top_tasks']))
          TaskStat.fromJson(_asMap(item)),
      ],
    );
  }

  final int activeStyles;
  final int totalRecords;
  final int checkInDays;
  final int currentStreak;
  final int longestStreak;
  final double completionRate;
  final Map<String, int> moodCounts;
  final List<TaskStat> topTasks;
}

class EssayStats {
  const EssayStats({
    required this.articles,
    required this.words,
    required this.activeDays,
    required this.avgWords,
    required this.topLabels,
    required this.moodCounts,
  });

  factory EssayStats.fromJson(Map<String, dynamic> json) {
    return EssayStats(
      articles: _asInt(json['articles']),
      words: _asInt(json['words']),
      activeDays: _asInt(json['active_days']),
      avgWords: _asDouble(json['avg_words']),
      topLabels: [
        for (final item in _asList(json['top_labels']))
          LabelStat.fromJson(_asMap(item)),
      ],
      moodCounts: _asIntMap(json['mood_counts']),
    );
  }

  final int articles;
  final int words;
  final int activeDays;
  final double avgWords;
  final List<LabelStat> topLabels;
  final Map<String, int> moodCounts;
}

class TaskStat {
  const TaskStat({
    required this.name,
    required this.done,
    required this.days,
  });

  factory TaskStat.fromJson(Map<String, dynamic> json) {
    return TaskStat(
      name: _asString(json['name']),
      done: _asInt(json['done']),
      days: _asInt(json['days']),
    );
  }

  final String name;
  final int done;
  final int days;
}

class LabelStat {
  const LabelStat({
    required this.name,
    required this.count,
  });

  factory LabelStat.fromJson(Map<String, dynamic> json) {
    return LabelStat(
      name: _asString(json['name']),
      count: _asInt(json['count']),
    );
  }

  final String name;
  final int count;
}

// 容错读取：键缺失或类型不符时回落到空值，避免后端契约演进直接崩在解析上。

String _asString(Object? value) {
  if (value == null) return '';
  if (value is String) return value;
  return value.toString();
}

String? _asStringOrNull(Object? value) =>
    value == null ? null : _asString(value);

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

double _asDouble(Object? value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

bool _asBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) return value == 'true' || value == '1';
  return false;
}

Map<String, dynamic> _asMap(Object? value) =>
    value is Map<String, dynamic> ? value : const <String, dynamic>{};

List<dynamic> _asList(Object? value) =>
    value is List ? value : const <dynamic>[];

List<String> _asStringList(Object? value) =>
    [for (final item in _asList(value)) _asString(item)];

Map<String, int> _asIntMap(Object? value) {
  if (value is! Map) return const <String, int>{};
  return {
    for (final entry in value.entries) entry.key.toString(): _asInt(entry.value),
  };
}
