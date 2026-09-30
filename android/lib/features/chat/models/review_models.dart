/// "近期回顾"的本地模型：预设镜像与已生成的回顾记录。
///
/// 生成的回顾只存本机（Hive），不外发；预设以服务端 `<STATIC_DIR>/data/review_presets.json`
/// 为权威，本机保存一份镜像，离线时仍能用镜像生成。
library;

import 'package:hive/hive.dart';

import 'package:torrid/core/utils/util.dart';

part 'review_models.g.dart';

/// 语气与角色预设。
@HiveType(typeId: 43)
class ReviewPreset {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  /// 角色设定：模型是谁、站在什么位置看这些记录。
  @HiveField(2)
  final String role;

  /// 语气要求：怎么说话。
  @HiveField(3)
  final String tone;

  ReviewPreset({
    required this.id,
    required this.name,
    required this.role,
    required this.tone,
  });

  /// 新建一条待编辑的预设（ID 先在本地生成，保存时随整体替换提交）。
  ReviewPreset.draft()
      : id = generateId(),
        name = '',
        role = '',
        tone = '';

  factory ReviewPreset.fromJson(Map<String, dynamic> json) => ReviewPreset(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        role: (json['role'] ?? '').toString(),
        tone: (json['tone'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role': role,
        'tone': tone,
      };

  ReviewPreset copyWith({String? name, String? role, String? tone}) =>
      ReviewPreset(
        id: id,
        name: name ?? this.name,
        role: role ?? this.role,
        tone: tone ?? this.tone,
      );

  /// 保存前的本地校验（与服务端的限制保持一致）。
  String? get problem {
    if (name.trim().isEmpty) return '预设名称不能为空';
    if (role.trim().isEmpty) return '角色设定不能为空';
    return null;
  }
}

/// 一条已生成的回顾。
@HiveType(typeId: 44)
class ReviewRecord {
  @HiveField(0)
  final String id;

  /// 生成时使用的预设名（预设改名或删除后，历史仍可读）。
  @HiveField(1)
  final String presetName;

  /// 具体起止日期，如 `2026-03-01 ~ 2026-03-30`。
  @HiveField(2)
  final String span;

  @HiveField(3)
  final DateTime createdAt;

  @HiveField(4)
  final String content;

  /// 本次依据的确定性统计（服务端 `stats` 事件原样保存，便于核对）。
  @HiveField(5)
  final String stats;

  ReviewRecord({
    required this.id,
    required this.presetName,
    required this.span,
    required this.createdAt,
    required this.content,
    required this.stats,
  });

  factory ReviewRecord.create({
    required String presetName,
    required String span,
    required String content,
    required String stats,
  }) =>
      ReviewRecord(
        id: generateId(),
        presetName: presetName,
        span: span,
        createdAt: DateTime.now(),
        content: content,
        stats: stats,
      );
}

/// 回顾的时间范围档位。
enum ReviewRangeKind {
  days7('近7天'),
  days30('近30天'),
  days90('近90天'),
  thisYear('今年'),
  custom('自定义');

  const ReviewRangeKind(this.label);

  final String label;
}

/// 一次回顾的时间范围。服务端接受 `from`/`to`（`YYYY-MM-DD`）或 `days`，
/// 与这里的换算保持一致：只给 days 时以"今天"为终点向前回溯。
class ReviewScope {
  const ReviewScope({
    this.kind = ReviewRangeKind.days30,
    this.from,
    this.to,
  });

  final ReviewRangeKind kind;
  final DateTime? from;
  final DateTime? to;

  /// 各档位对应的天数（自定义档不使用）。
  static const Map<ReviewRangeKind, int> _days = {
    ReviewRangeKind.days7: 7,
    ReviewRangeKind.days30: 30,
    ReviewRangeKind.days90: 90,
  };

  /// 自定义档是否已选好起止日期。
  bool get isComplete {
    if (kind != ReviewRangeKind.custom) return true;
    return from != null && to != null && !from!.isAfter(to!);
  }

  /// 服务端请求字段。
  Map<String, dynamic> toRequestFields(DateTime today) {
    final days = _days[kind];
    if (days != null) return {'days': days};
    final span = resolve(today);
    return {'from': span.from, 'to': span.to};
  }

  /// 换算成具体起止日期（本机与服务端同一时区，"今天"一致）。
  ({String from, String to}) resolve(DateTime today) {
    if (kind == ReviewRangeKind.thisYear) {
      return (from: '${today.year}-01-01', to: _format(today));
    }
    if (kind == ReviewRangeKind.custom && from != null && to != null) {
      return (from: _format(from!), to: _format(to!));
    }
    final days = _days[kind] ?? 30;
    return (from: _format(today.subtract(Duration(days: days - 1))), to: _format(today));
  }

  /// 供界面与历史记录展示的范围描述。
  String describe(DateTime today) {
    final span = resolve(today);
    return '${span.from} ~ ${span.to}';
  }

  static String _format(DateTime date) {
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '${date.year}-$m-$d';
  }
}
