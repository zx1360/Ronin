/// 用户数据（随笔 / 打卡）的双向增量同步原语。
///
/// 服务端语义（`/API/user-data/*`）：
/// - `GET /sync/:module` 返回**全部行（含墓碑）**，每行带 `created_at`/`updated_at`/
///   `deleted_at`（`deleted_at` 非空即墓碑）；
/// - `POST /backup/:module` 按 `updated_at` **逐行合并**：严格更新才覆盖，等值为
///   幂等空操作；载荷里缺席的行保持不动，因此"删除"只能靠墓碑传播。
///
/// 客户端因此不能再用"清空 + 重写"的整表替换，必须逐行比较时间戳后合并。
/// 本文件只放**与存储无关**的纯逻辑，便于单测且被两个模块共用：
/// - [SyncRow]：行携带同步元数据的统一视图；
/// - [parseSyncRows]：先把服务端数组整体解析校验，任何一条非法都直接抛出（写库前）；
/// - [planSyncMerge]：纯函数地算出"要写哪些行、跳过哪些行"；
/// - [applySyncMergePlan]：把计划落到 `存储键 -> 行` 映射（测试与落库共用同一语义）；
/// - [touchSyncTimes] / [tombstoneSyncTimes] / [packUserData]：本地写入与上传的共用约定。
library;

import 'dart:convert';

/// 同步时间戳的 wire 形态：统一为 UTC ISO8601（带 `Z`），本地一律用本地时间。
///
/// 与本项目 [dateTimeFromJson]/[dateTimeToJson] 的约定一致：绝对时刻往返无损，
/// 不因时区偏移在多次同步间漂移。
DateTime? syncTimeFromJson(String? value) {
  if (value == null) return null;
  final text = value.trim();
  if (text.isEmpty) return null;
  return DateTime.parse(text).toLocal();
}

/// 同步时间戳序列化；null 保持 null（服务端把"缺失"视为未删除 / 由服务端补时间）。
String? syncTimeToJson(DateTime? value) => value?.toUtc().toIso8601String();

/// 一行可同步数据的最小视图。
///
/// 由各持久化模型实现（[Essay]、[Label]、[YearSummary]、[Style]、[Record]）。
abstract interface class SyncRow {
  /// 本地 Hive 的存储键：随笔/标签/样式/记录 = `id`，年度汇总 = `year`。
  String get syncStorageKey;

  /// 服务端的合并身份：多数表就是 `id`，打卡记录是 `style_id + date`。
  String get syncMatchKey;

  /// 首次写入时间（服务端缺省时可能为 null）。
  DateTime? get syncCreatedAt;

  /// 最后修改时间；null 视为最旧（服务端会补时间后回传）。
  DateTime? get syncUpdatedAt;

  /// 墓碑时间；非空表示"已删除"，仅用于同步，UI 必须过滤掉这类行。
  DateTime? get syncDeletedAt;
}

/// [SyncRow] 的派生判断：墓碑行对用户不可见。
extension SyncRowStatus on SyncRow {
  bool get isTombstone => syncDeletedAt != null;
}

/// 同步时间的公共基准：null 一律当作"最早"，让任何真实时间戳都能覆盖它。
final DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

/// 解析服务端下发的行数组。
///
/// 刻意做成"先整体解析校验"：任何一条非法都会在调用方写库之前抛出，
/// 保证不会出现"清空/写了一半才发现数据非法"的中间态。
List<T> parseSyncRows<T>(
  Object? raw,
  T Function(Map<String, dynamic> json) fromJson, {
  required String field,
}) {
  if (raw is! List) {
    throw FormatException('同步数据缺少 $field 列表');
  }
  final rows = <T>[];
  for (final item in raw) {
    if (item is! Map<String, dynamic>) {
      throw FormatException('$field 中存在非对象行');
    }
    rows.add(fromJson(item));
  }
  return rows;
}

/// 一次合并的计划：算出后由调用方在**一次 Hive 写入**里落地。
class SyncMergePlan<T extends SyncRow> {
  const SyncMergePlan({
    required this.upserts,
    required this.removals,
    required this.applied,
    required this.skipped,
  });

  /// 存储键 -> 要写入的行（含墓碑）。
  final Map<String, T> upserts;

  /// 需要删除的旧存储键（仅"同一逻辑行换了存储键"时出现）。
  final List<String> removals;

  /// 实际写入的行数（含插入、覆盖与墓碑）。
  final int applied;

  /// 因本地版本不旧于服务端而被忽略的行数。
  final int skipped;

  /// 本次服务端下发的行数。
  int get received => applied + skipped;

  bool get isEmpty => upserts.isEmpty && removals.isEmpty;
}

/// 计算逐行合并计划（纯函数，不触碰任何存储）。
///
/// 规则（与服务端一致）：
/// - 本地没有该逻辑行 → 插入（含墓碑，保留"已删除"的知识，避免被更旧的本地行复活）；
/// - 服务端行 `updated_at` **严格更新** → 覆盖，墓碑同样照写（本地随即不可见）；
/// - `updated_at` 相等或更旧 → 忽略；
/// - 时间戳相等但存储键不同（打卡记录的服务端业务键是 `style_id + date`，
///   服务端会采纳传入的 `id`）→ 记一条 removals 把本地键对齐到服务端下发的行，
///   否则同一业务键会在本地留下两行。
SyncMergePlan<T> planSyncMerge<T extends SyncRow>({
  required Iterable<T> local,
  required List<T> incoming,
}) {
  final byMatchKey = <String, T>{};
  for (final row in local) {
    byMatchKey[row.syncMatchKey] = row;
  }

  final upserts = <String, T>{};
  final removals = <String>{};
  var applied = 0;
  var skipped = 0;

  for (final row in incoming) {
    final existing = byMatchKey[row.syncMatchKey];

    if (existing == null) {
      upserts[row.syncStorageKey] = row;
      applied++;
      continue;
    }

    final incomingIsNewer = (row.syncUpdatedAt ?? _epoch).isAfter(
      existing.syncUpdatedAt ?? _epoch,
    );
    if (incomingIsNewer) {
      if (existing.syncStorageKey != row.syncStorageKey) {
        removals.add(existing.syncStorageKey);
      }
      upserts[row.syncStorageKey] = row;
      applied++;
      continue;
    }

    final sameVersionOtherKey =
        existing.syncStorageKey != row.syncStorageKey &&
        !(existing.syncUpdatedAt ?? _epoch).isAfter(row.syncUpdatedAt ?? _epoch);
    if (sameVersionOtherKey) {
      // 同一版本、不同存储键：不是数据变更，只是键对齐。
      removals.add(existing.syncStorageKey);
      upserts[row.syncStorageKey] = row;
      applied++;
      continue;
    }

    skipped++;
  }

  return SyncMergePlan<T>(
    upserts: upserts,
    removals: removals.toList(),
    applied: applied,
    skipped: skipped,
  );
}

/// 把计划应用到一个 `存储键 -> 行` 映射上（纯函数；测试与落库共用同一语义）。
Map<String, T> applySyncMergePlan<T extends SyncRow>(
  Map<String, T> current,
  SyncMergePlan<T> plan,
) {
  final next = Map<String, T>.of(current);
  for (final key in plan.removals) {
    next.remove(key);
  }
  next.addAll(plan.upserts);
  return next;
}

/// 只保留"活"行：墓碑不得参与 UI 展示与派生统计。
Iterable<T> liveSyncRows<T extends SyncRow>(Iterable<T> rows) =>
    rows.where((row) => !row.isTombstone);

/// 本地新增/修改一行时应写入的时间戳：`created_at` 首次落定，`updated_at` 每次刷新。
({DateTime? createdAt, DateTime updatedAt}) touchSyncTimes(
  DateTime? existingCreatedAt,
) {
  final now = DateTime.now();
  return (createdAt: existingCreatedAt ?? now, updatedAt: now);
}

/// 本地删除一行时的墓碑时间戳：`updated_at` 与 `deleted_at` 同为删除时刻，
/// 保证墓碑能盖过本地已知的任何版本，删除才能传播出去。
({DateTime? createdAt, DateTime updatedAt, DateTime deletedAt})
tombstoneSyncTimes(DateTime? existingCreatedAt) {
  final now = DateTime.now();
  return (createdAt: existingCreatedAt ?? now, updatedAt: now, deletedAt: now);
}

/// 打包一个模块的全部本地行（**含墓碑**）为备份载荷。
///
/// 服务端逐行合并、载荷里缺席的行保持不动，所以必须把墓碑一并上报，
/// "在另一端删除"才会生效；同时每行都带 `created_at`/`updated_at`/`deleted_at`，
/// 时间戳由模型的 `toJson` 统一产出，各模块无需各写一份。
Map<String, dynamic> packUserData(
  Map<String, List<Map<String, dynamic>>> collections,
) {
  return {'jsonData': jsonEncode(collections)};
}
