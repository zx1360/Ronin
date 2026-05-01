import 'dart:async';

import 'package:northstar/application/ops/providers/core_services_provider.dart';
import 'package:northstar/domain/ops/models/ops_settings.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ops_settings_provider.g.dart';

@Riverpod(keepAlive: true)
class OpsSettingsController extends _$OpsSettingsController {
  @override
  OpsSettings build() {
    Future<void>(() async {
      final repository = ref.read(opsPersistenceRepositoryProvider);
      final cached = await repository.loadSettings();
      if (cached == null) {
        await repository.saveSettings(state);
        return;
      }
      state = cached;
    });
    return OpsSettings.defaults();
  }

  Future<void> update({
    String? apiBaseUrl,
    String? apiKey,
    int? autoRefreshSeconds,
    bool? hideApiKey,
  }) async {
    state = state.copyWith(
      apiBaseUrl: apiBaseUrl,
      apiKey: apiKey,
      autoRefreshSeconds: autoRefreshSeconds,
      hideApiKey: hideApiKey,
    );
    await _save();
  }

  Future<void> _save() async {
    final repository = ref.read(opsPersistenceRepositoryProvider);
    await repository.saveSettings(state);
  }
}
