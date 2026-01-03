import 'package:hive/hive.dart';
import 'changya_user.dart';
import 'changya_song.dart';
import 'changya_audio.dart';

@HiveType(typeId: 63)
class ChangyaRecord {
  // 用 publishAt 作为唯一标识
  @HiveField(0)
  String id;
  @HiveField(1)
  ChangyaUser? user;
  @HiveField(2)
  ChangyaSong? song;
  @HiveField(3)
  ChangyaAudio? audio;

  ChangyaRecord({required this.id, this.user, this.song, this.audio});
}

class ChangyaRecordAdapter extends TypeAdapter<ChangyaRecord> {
  @override
  final int typeId = 63;

  @override
  ChangyaRecord read(BinaryReader reader) {
    final id = reader.read() as String;
    final user = reader.read() as ChangyaUser?;
    final song = reader.read() as ChangyaSong?;
    final audio = reader.read() as ChangyaAudio?;
    return ChangyaRecord(id: id, user: user, song: song, audio: audio);
  }

  @override
  void write(BinaryWriter writer, ChangyaRecord obj) {
    writer..write(obj.id)..write(obj.user)..write(obj.song)..write(obj.audio);
  }
}
