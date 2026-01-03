import 'package:hive/hive.dart';

@HiveType(typeId: 61)
class ChangyaSong {
  @HiveField(0)
  String? name;
  @HiveField(1)
  String? singer;
  @HiveField(2)
  List<String> lyrics;

  ChangyaSong({this.name, this.singer, List<String>? lyrics}) : lyrics = lyrics ?? const [];
}

class ChangyaSongAdapter extends TypeAdapter<ChangyaSong> {
  @override
  final int typeId = 61;

  @override
  ChangyaSong read(BinaryReader reader) {
    final name = reader.read() as String?;
    final singer = reader.read() as String?;
    final lyrics = (reader.read() as List?)?.map((e) => e.toString()).toList() ?? <String>[];
    return ChangyaSong(name: name, singer: singer, lyrics: lyrics);
  }

  @override
  void write(BinaryWriter writer, ChangyaSong obj) {
    writer..write(obj.name)..write(obj.singer)..write(obj.lyrics);
  }
}
