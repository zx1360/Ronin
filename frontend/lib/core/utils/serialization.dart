// DateTime 序列化相关工具。
//
// 项目中的"日期"字段分为两类，必须区分对待：
//
// 1. 日历日期（无时间概念）——如 booklet 的 style.start_date、record.date，
//    使用 [dateFromJson]/[dateToJson]，以 `yyyy-MM-dd` 形式传输。
//    避免旧实现"本地时间无时区字符串被服务端当作 UTC 解析、同步回来又 toLocal 加回偏移"
//    导致每次备份/同步往返累积 +8h 漂移的问题。
//
// 2. 带时间的时刻——如 essay.date、message.timestamp（界面展示到分钟），
//    使用 [dateTimeFromJson]/[dateTimeToJson]，以带时区信息的 ISO8601 传输，往返无损。

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
