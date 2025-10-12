import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/core/services/storage/prefs_service.dart';

import 'package:torrid/core/services/storage/user_pref_provider/app_setting.dart';

part 'app_settings_provider.g.dart';

@riverpod
class AppSettingsProvider extends _$AppSettingsProvider {
  @override
  AppSettings build() {
    return AppSettings();
  }

  Future<void> loadSettings() async {
    final prefs = await PrefsService.prefs;
    final stringPrefs = prefs.getString("preferences");
    state = AppSettings.fromJson(jsonDecode(stringPrefs ?? ""));
  }

  Future<void> saveSettings() async {
    final prefs = await PrefsService.prefs;
    await prefs.setString("preferences", jsonEncode(state.toJson()));
  }
}
