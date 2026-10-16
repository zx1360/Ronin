import 'dart:convert';

import 'package:torrid/core/services/personalization/personalization_service.dart';
import 'package:torrid/core/services/storage/prefs_service.dart';
import 'package:torrid/providers/network_config/network_config_provider.dart';

Map<String, dynamic> packPreferences(NetworkConfigState network) {
  final settings = PersonalizationService().getSettings();
  return {
    'backgroundImages': settings.backgroundImages,
    'sidebarImages': settings.sidebarImages,
    'mottos': settings.mottos,
    'nickname': settings.nickname,
    'signature': settings.signature,
    'avatarPath': settings.avatarPath ?? '',
    'networkConfig': {
      'apiKey': network.apiKey,
      'hostList': jsonEncode(
        network.configs.map((host) => host.toJson()).toList(),
      ),
      'activeIndex': network.activeIndex,
    },
  };
}

List<String> preferenceImagePaths(Map<String, dynamic> data) => [
  ...List<String>.from(data['backgroundImages'] as List? ?? []),
  ...List<String>.from(data['sidebarImages'] as List? ?? []),
  if ((data['avatarPath'] as String?)?.isNotEmpty == true)
    data['avatarPath'] as String,
];

Future<void> restorePreferences(Map<String, dynamic> data) async {
  final prefs = PrefsService().prefs;
  final next = AppSettings.fromJson(data);
  if (next.avatarPath?.isEmpty == true) next.avatarPath = null;
  final updates = <String, Object>{'preferences': jsonEncode(next.toJson())};
  final network = data['networkConfig'] as Map?;
  if (network != null) {
    final apiKey = network['apiKey'];
    final hostList = network['hostList'];
    final activeIndex = network['activeIndex'];
    if (apiKey is! String || hostList is! String || activeIndex is! int) {
      throw const FormatException('偏好的网络配置无效');
    }
    final hosts = hostList.isEmpty ? <dynamic>[] : jsonDecode(hostList);
    if (hosts is! List ||
        activeIndex < 0 ||
        (hosts.isEmpty ? activeIndex != 0 : activeIndex >= hosts.length) ||
        hosts.any(
          (host) =>
              host is! Map ||
              host['host'] is! String ||
              host['port'] is! String,
        )) {
      throw const FormatException('偏好的主机列表或激活下标无效');
    }
    updates.addAll({
      'API_KEY': apiKey,
      'PC_HOST_LIST': hostList,
      'PC_ACTIVE_INDEX': activeIndex,
    });
  }
  final previous = {for (final key in updates.keys) key: prefs.get(key)};
  Future<void> write(String key, Object? value) async {
    final saved = switch (value) {
      String() => await prefs.setString(key, value),
      int() => await prefs.setInt(key, value),
      null => await prefs.remove(key),
      _ => throw StateError('不支持的偏好类型'),
    };
    if (!saved) throw StateError('保存偏好失败: $key');
  }

  try {
    for (final entry in updates.entries) {
      await write(entry.key, entry.value);
    }
  } catch (error) {
    final failures = <Object>[];
    for (final entry in previous.entries) {
      try {
        await write(entry.key, entry.value);
      } catch (restoreError) {
        failures.add(restoreError);
      }
    }
    if (failures.isNotEmpty) {
      throw StateError('偏好恢复失败且回退失败: $error; $failures');
    }
    rethrow;
  }
}
