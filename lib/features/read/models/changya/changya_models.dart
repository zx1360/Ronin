class ChangyaUser {
  final String? nickname;
  final String? gender;
  final String? avatarUrl; // 可能是网络URL或以'/'开头的本地相对路径

  ChangyaUser({this.nickname, this.gender, this.avatarUrl});

  factory ChangyaUser.fromJson(Map<String, dynamic> json) => ChangyaUser(
        nickname: json['nickname'] as String?,
        gender: json['gender'] as String?,
        avatarUrl: json['avatar_url'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'nickname': nickname,
        'gender': gender,
        'avatar_url': avatarUrl,
      };
}

class ChangyaSong {
  final String? name;
  final String? singer;
  final List<String> lyrics;

  ChangyaSong({this.name, this.singer, List<String>? lyrics}) : lyrics = lyrics ?? const [];

  factory ChangyaSong.fromJson(Map<String, dynamic> json) => ChangyaSong(
        name: json['name'] as String?,
        singer: json['singer'] as String?,
        lyrics: (json['lyrics'] is List)
            ? (json['lyrics'] as List).map((e) => e.toString()).toList()
            : const [],
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'singer': singer,
        'lyrics': lyrics,
      };
}

class ChangyaAudio {
  final String? url; // 可能是网络URL或以'/'开头的本地相对路径
  final int? duration; // 毫秒
  final int? likeCount;
  final String? link; // 来源链接
  final String? publish; // 文本时间
  final int? publishAt; // 时间戳

  ChangyaAudio({this.url, this.duration, this.likeCount, this.link, this.publish, this.publishAt});

  factory ChangyaAudio.fromJson(Map<String, dynamic> json) => ChangyaAudio(
        url: json['url']?.toString(),
        duration: (json['duration'] is int) ? json['duration'] as int : int.tryParse('${json['duration']}'),
        likeCount: (json['like_count'] is int) ? json['like_count'] as int : int.tryParse('${json['like_count']}'),
        link: json['link']?.toString(),
        publish: json['publish']?.toString(),
        publishAt: (json['publish_at'] is int) ? json['publish_at'] as int : int.tryParse('${json['publish_at']}'),
      );

  Map<String, dynamic> toJson() => {
        'url': url,
        'duration': duration,
        'like_count': likeCount,
        'link': link,
        'publish': publish,
        'publish_at': publishAt,
      };
}

class ChangyaData {
  final ChangyaUser? user;
  final ChangyaSong? song;
  final ChangyaAudio? audio;

  ChangyaData({this.user, this.song, this.audio});

  factory ChangyaData.fromJson(Map<String, dynamic> json) => ChangyaData(
        user: json['user'] is Map ? ChangyaUser.fromJson((json['user'] as Map).cast<String, dynamic>()) : null,
        song: json['song'] is Map ? ChangyaSong.fromJson((json['song'] as Map).cast<String, dynamic>()) : null,
        audio: json['audio'] is Map ? ChangyaAudio.fromJson((json['audio'] as Map).cast<String, dynamic>()) : null,
      );

  Map<String, dynamic> toJson() => {
        'user': user?.toJson(),
        'song': song?.toJson(),
        'audio': audio?.toJson(),
      }..removeWhere((k, v) => v == null);
}
