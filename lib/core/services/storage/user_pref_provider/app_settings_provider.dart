import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/core/services/storage/prefs_service.dart';

import 'package:torrid/core/services/storage/user_pref_provider/app_setting.dart';

part 'app_settings_provider.g.dart';

@riverpod
class AppSettingsProvider extends _$AppSettingsProvider {
  @override
  AppSettings build() {
    final prefs = PrefsService.prefs;
    final stringPrefs = prefs.getString("preferences");
    return AppSettings.fromJson(jsonDecode(stringPrefs!));
  }

  // 初始化, 如果记录中没有值就赋予初值.
  Future<void> initSettings()async{
    final prefs = PrefsService.prefs;
    if(!prefs.containsKey("preferences")){
      state = AppSettings.defaultValue();
      await saveSettings();
    }
  }

  // 存/读
  void loadSettings() {
    final prefs = PrefsService.prefs;
    final stringPrefs = prefs.getString("preferences");
    state = AppSettings.fromJson(jsonDecode(stringPrefs!));
  }

  Future<void> saveSettings() async {
    final prefs = PrefsService.prefs;
    await prefs.setString("preferences", jsonEncode(state.toJson()));
  }
}
