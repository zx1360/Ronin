import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';


part 'prefs_service.g.dart';

// 偏好设置数据类.
@JsonSerializable()
class AppSettings {
  // northstar传输相关.
  String ip;
  String port;
  
  // 外观相关 - 背景图片（共用于SplashPage/HomePage）
  // 存储相对路径，如 "preferences/background/xxx.jpg"
  List<String> backgroundImages;
  
  // 外观相关 - 侧边栏背景图片
  List<String> sidebarImages;
  
  // 座右铭列表
  List<String> mottos;
  
  // 用户信息
  String nickname;
  String signature;
  // 头像图片路径，为空时使用默认
  String? avatarPath;
  
  AppSettings({
    required this.ip,
    required this.port,
    required this.backgroundImages,
    required this.sidebarImages,
    required this.mottos,
    required this.nickname,
    required this.signature,
    this.avatarPath,
  });

  // copyWith方法
  AppSettings copyWith({
    String? ip,
    String? port,
    List<String>? backgroundImages,
    List<String>? sidebarImages,
    List<String>? mottos,
    String? nickname,
    String? signature,
    String? avatarPath,
    bool clearAvatar = false,
  }) {
    return AppSettings(
      ip: ip ?? this.ip,
      port: port ?? this.port,
      backgroundImages: backgroundImages ?? this.backgroundImages,
      sidebarImages: sidebarImages ?? this.sidebarImages,
      mottos: mottos ?? this.mottos,
      nickname: nickname ?? this.nickname,
      signature: signature ?? this.signature,
      avatarPath: clearAvatar ? null : (avatarPath ?? this.avatarPath),
    );
  }

  // 偏好默认值
  factory AppSettings.defaultValue() {
    return AppSettings(
      ip: "",
      port: "",
      backgroundImages: [],
      sidebarImages: [],
      mottos: ["理想如星\n虽不能及,吾心往之"],
      nickname: "未设置昵称",
      signature: "这个人很懒，什么都没写~",
      avatarPath: null,
    );
  }

  // json序列化/反序列化.
  factory AppSettings.fromJson(dynamic json) => _$AppSettingsFromJson(json);
  Map<String, dynamic> toJson() => _$AppSettingsToJson(this);
}

class PrefsService {
  // 饿汉式单例
  static final PrefsService _instance = PrefsService._();
  PrefsService._();
  // 静态唯一实例
  factory PrefsService() => _instance;

  // 由此管理的唯一对象
  late SharedPreferences _prefs;
  SharedPreferences get prefs {
    return _prefs;
  }

  // 初始化prefs值
  Future<void> initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    await _ensureSettingsHasValue();
  }

  // 确保偏好设置preferences有值.
  Future<void> _ensureSettingsHasValue() async {
    if (!_prefs.containsKey("preferences") ||
        _prefs.getString("preferences") == "") {
      final settings = AppSettings.defaultValue();
      await _prefs.setString("preferences", jsonEncode(settings.toJson()));
    }
  }
}
