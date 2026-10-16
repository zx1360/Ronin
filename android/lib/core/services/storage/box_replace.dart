import 'package:hive/hive.dart';

const boxWriteJournal = 'boxWriteJournal';
Future<void> _pending = Future.value();

Future<void> _writeBoxes(
  Map<Box<dynamic>, Map<dynamic, dynamic>> contents,
) async {
  for (final entry in contents.entries) {
    // 日志反序列化会擦除 Map 泛型，沿用 Box 自身的值类型。
    final values = entry.key.toMap()..clear();
    for (final row in entry.value.entries) {
      values[row.key] = row.value;
    }
    await entry.key.putAll(values);
    await entry.key.deleteAll(
      entry.key.keys.where((key) => !entry.value.containsKey(key)).toList(),
    );
    await entry.key.flush();
  }
}

/// 启动时回滚尚未完成的多 Box 写入，恢复成功后才开放编辑和同步。
Future<void> recoverBoxWrites(Iterable<Box<dynamic>> boxes) async {
  final journal = await Hive.openBox<dynamic>(boxWriteJournal);
  final previous = journal.get('previous') as Map?;
  if (previous == null) return;
  final byName = {for (final box in boxes) box.name: box};
  await _writeBoxes({
    for (final entry in previous.entries)
      byName[entry.key] ?? (throw StateError('恢复所需的数据箱未打开：${entry.key}')):
          Map<dynamic, dynamic>.from(entry.value as Map),
  });
  await journal.delete('previous');
  await journal.flush();
}

/// 全部数据应先解析完成；持久化原内容后提交，异常或进程中断均可回滚。
Future<void> replaceBoxes(
  Map<Box<dynamic>, Map<dynamic, dynamic>> replacements,
) {
  final result = _pending.then((_) => _replaceBoxes(replacements));
  _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
  return result;
}

Future<void> _replaceBoxes(
  Map<Box<dynamic>, Map<dynamic, dynamic>> replacements,
) async {
  if (replacements.length < 2) return _writeBoxes(replacements);
  final journal = await Hive.openBox<dynamic>(boxWriteJournal);
  if (journal.containsKey('previous')) {
    throw StateError('上次数据写入尚未恢复，请重启应用后再试');
  }
  final previous = {for (final box in replacements.keys) box: box.toMap()};
  await journal.put('previous', {
    for (final entry in previous.entries) entry.key.name: entry.value,
  });
  await journal.flush();
  try {
    await _writeBoxes(replacements);
    await journal.delete('previous');
    await journal.flush();
  } catch (_) {
    await _writeBoxes(previous);
    await journal.delete('previous');
    await journal.flush();
    rethrow;
  }
}
