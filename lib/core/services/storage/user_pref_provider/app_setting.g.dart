// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_setting.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppSettings _$AppSettingsFromJson(Map<String, dynamic> json) => AppSettings(
      ip: json['ip'] as String,
      port: json['port'] as String,
      motto: json['motto'] as String,
      bgImgRelativePaths: (json['bgImgRelativePaths'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$AppSettingsToJson(AppSettings instance) =>
    <String, dynamic>{
      'ip': instance.ip,
      'port': instance.port,
      'motto': instance.motto,
      'bgImgRelativePaths': instance.bgImgRelativePaths,
    };
