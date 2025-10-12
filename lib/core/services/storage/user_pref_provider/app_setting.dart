import 'package:json_annotation/json_annotation.dart';

part 'app_setting.g.dart';

// 偏好设置数据类.
@JsonSerializable()
class AppSettings {
  // northstar传输相关.
  String ip;
  String port;
  // 外观相关.(HomePage首页)
  String motto;
  List<String> bgImgRelativePaths;
  AppSettings({
    required this.ip,
    required this.port,
    required this.motto,
    required this.bgImgRelativePaths,
  });

  // copyWith方法
  AppSettings copyWith({
    String? ip,
    String? port,
    String? motto,
    List<String>? bgImgRelativePaths,
  }) {
    return AppSettings(
      ip: ip ?? this.ip,
      port: port ?? this.port,
      motto: motto ?? this.motto,
      bgImgRelativePaths: bgImgRelativePaths ?? this.bgImgRelativePaths,
    );
  }

  // 偏好认值
  factory AppSettings.defaultValue() {
    return AppSettings(
      ip: "",
      port: "",
      motto: "理想如星, 虽不能及, 吾心往之.",
      bgImgRelativePaths: ["assets/images/1.jpg"],
    );
  }

  // json序列化/反序列化.
  factory AppSettings.fromJson(dynamic json) => _$AppSettingsFromJson(json);
  Map<String, dynamic> toJson() => _$AppSettingsToJson(this);
}
