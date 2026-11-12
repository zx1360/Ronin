import 'package:drift/drift.dart';

class EpochMicros extends TypeConverter<DateTime, int> {
  const EpochMicros();

  @override
  DateTime fromSql(int fromDb) =>
      DateTime.fromMicrosecondsSinceEpoch(fromDb, isUtc: true);

  @override
  int toSql(DateTime value) => value.microsecondsSinceEpoch;
}
