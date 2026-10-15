import 'package:hive/hive.dart';

/// 全部数据应先解析完成；多 Box 写入失败时恢复原内容。
Future<void> replaceBoxes(
  Map<Box<dynamic>, Map<dynamic, dynamic>> replacements,
) async {
  final previous = {for (final box in replacements.keys) box: box.toMap()};
  Future<void> write(Map<Box<dynamic>, Map<dynamic, dynamic>> contents) async {
    for (final entry in contents.entries) {
      await entry.key.putAll(entry.value);
      await entry.key.deleteAll(
        entry.key.keys.where((key) => !entry.value.containsKey(key)).toList(),
      );
    }
  }

  try {
    await write(replacements);
  } catch (_) {
    await write(previous);
    rethrow;
  }
}
