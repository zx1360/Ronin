import 'package:hive/hive.dart';

@HiveType(typeId: 60)
class ChangyaUser {
  @HiveField(0)
  String? nickname;
  @HiveField(1)
  String? gender;
  @HiveField(2)
  String? avatarUrl; // 相对路径或网络地址

  ChangyaUser({this.nickname, this.gender, this.avatarUrl});
}

class ChangyaUserAdapter extends TypeAdapter<ChangyaUser> {
  @override
  final int typeId = 60;

  @override
  ChangyaUser read(BinaryReader reader) {
    final nickname = reader.read() as String?;
    final gender = reader.read() as String?;
    final avatarUrl = reader.read() as String?;
    return ChangyaUser(nickname: nickname, gender: gender, avatarUrl: avatarUrl);
  }

  @override
  void write(BinaryWriter writer, ChangyaUser obj) {
    writer..write(obj.nickname)..write(obj.gender)..write(obj.avatarUrl);
  }
}
