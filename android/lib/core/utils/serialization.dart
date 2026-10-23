// 日历日（booklet）不做时区换算；时刻（essay/message）按 UTC ISO8601 往返。

/// 解析日历日期字符串，统一规整为本地"年-月-日"（丢弃时分秒）。
///
/// 兼容 `yyyy-MM-dd` 与 RFC3339（`yyyy-MM-ddTHH:mm:ss(.sss)(Z|±HH:MM)`）两种输入，
/// 后者取解析结果自身的年/月/日字段（对服务端返回的 UTC 零点即所表达的那个日历日）。
DateTime dateFromJson(String dateStr) {
  final parsed = DateTime.parse(dateStr);
  return DateTime(parsed.year, parsed.month, parsed.day);
}

/// 序列化日历日期为 `yyyy-MM-dd`。
///
/// 直接取字段值拼装、不做任何时区换算，保证同一日期在任何时区、任何往返下都得到相同字符串。
String dateToJson(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// 解析带时间的时刻，规整为本地时间（与服务端存储的绝对时刻一致）。
DateTime dateTimeFromJson(String dateStr) => DateTime.parse(dateStr).toLocal();

/// 序列化带时间的时刻为 UTC ISO8601 字符串（绝对时刻，往返无损）。
String dateTimeToJson(DateTime date) => date.toUtc().toIso8601String();
