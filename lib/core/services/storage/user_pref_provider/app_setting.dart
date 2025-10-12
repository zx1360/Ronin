import 'package:json_annotation/json_annotation.dart';

part 'app_setting.g.dart';

// 到时候支持自定义一系列壁纸轮播/随机展示. 之类的偏好设置都放这里.
@JsonSerializable()
class AppSettings {
  String? ip;
  String? port;
  AppSettings({this.ip, this.port});

  factory AppSettings.fromJson(dynamic json) => _$AppSettingsFromJson(json);
  Map<String, dynamic> toJson() => _$AppSettingsToJson(this);
}
