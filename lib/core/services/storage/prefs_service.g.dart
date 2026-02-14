// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'prefs_service.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppSettings _$AppSettingsFromJson(Map<String, dynamic> json) => AppSettings(
      ip: json['ip'] as String? ?? '',
      port: json['port'] as String? ?? '',
      backgroundImages: (json['backgroundImages'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [],
      sidebarImages: (json['sidebarImages'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [],
      mottos: (json['mottos'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? ["理想如星\n虽不能及,吾心往之"],
      nickname: json['nickname'] as String? ?? "未设置昵称",
      signature: json['signature'] as String? ?? "这个人很懒，什么都没写~",
      avatarPath: json['avatarPath'] as String?,
    );

Map<String, dynamic> _$AppSettingsToJson(AppSettings instance) =>
    <String, dynamic>{
      'ip': instance.ip,
      'port': instance.port,
      'backgroundImages': instance.backgroundImages,
      'sidebarImages': instance.sidebarImages,
      'mottos': instance.mottos,
      'nickname': instance.nickname,
      'signature': instance.signature,
      'avatarPath': instance.avatarPath,
    };
