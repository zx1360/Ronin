import 'package:hive/hive.dart';

@HiveType(typeId: 62)
class ChangyaAudio {
  @HiveField(0)
  String? url; // 相对路径或网络地址
  @HiveField(1)
  int? duration;
  @HiveField(2)
  int? likeCount;
  @HiveField(3)
  String? link;
  @HiveField(4)
  String? publish;
  @HiveField(5)
  int? publishAt;

  ChangyaAudio({this.url, this.duration, this.likeCount, this.link, this.publish, this.publishAt});
}

class ChangyaAudioAdapter extends TypeAdapter<ChangyaAudio> {
  @override
  final int typeId = 62;

  @override
  ChangyaAudio read(BinaryReader reader) {
    final url = reader.read() as String?;
    final duration = reader.read() as int?;
    final likeCount = reader.read() as int?;
    final link = reader.read() as String?;
    final publish = reader.read() as String?;
    final publishAt = reader.read() as int?;
    return ChangyaAudio(
      url: url,
      duration: duration,
      likeCount: likeCount,
      link: link,
      publish: publish,
      publishAt: publishAt,
    );
  }

  @override
  void write(BinaryWriter writer, ChangyaAudio obj) {
    writer
      ..write(obj.url)
      ..write(obj.duration)
      ..write(obj.likeCount)
      ..write(obj.link)
      ..write(obj.publish)
      ..write(obj.publishAt);
  }
}
