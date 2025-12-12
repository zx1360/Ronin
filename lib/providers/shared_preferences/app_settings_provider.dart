import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/core/services/storage/prefs_service.dart';

part 'app_settings_provider.g.dart';

// 全局provider, 让整个应用能够实时获取.
@riverpod
class AppSettingsProvider extends _$AppSettingsProvider {
  @override
  AppSettings build() {
    final prefs = PrefsService().prefs;
    final stringPrefs = prefs.getString("preferences");
    return AppSettings.fromJson(jsonDecode(stringPrefs!));
  }

  // 存/读
  void loadSettings() {
    final prefs = PrefsService().prefs;
    final stringPrefs = prefs.getString("preferences");
    state = AppSettings.fromJson(jsonDecode(stringPrefs!));
  }

  Future<void> saveSettings() async {
    final prefs = PrefsService().prefs;
    await prefs.setString("preferences", jsonEncode(state.toJson()));
  }
}
