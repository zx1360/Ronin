import 'package:torrid/core/services/personalization/personalization_service.dart';
import 'package:torrid/core/services/storage/prefs_service.dart';

Map<String, dynamic> packPreferences() {
  final settings = PersonalizationService().getSettings();
  final prefs = PrefsService().prefs;
  return {
    'backgroundImages': settings.backgroundImages,
    'sidebarImages': settings.sidebarImages,
    'mottos': settings.mottos,
    'nickname': settings.nickname,
    'signature': settings.signature,
    'avatarPath': settings.avatarPath ?? '',
    'networkConfig': {
      'apiKey': prefs.getString('API_KEY') ?? '',
      'hostList': prefs.getString('PC_HOST_LIST') ?? '',
      'activeIndex': prefs.getInt('PC_ACTIVE_INDEX') ?? 0,
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
  final service = PersonalizationService();
  final previous = service.getSettings();
  final prefs = PrefsService().prefs;
  final previousNetwork = {
    for (final key in ['API_KEY', 'PC_HOST_LIST', 'PC_ACTIVE_INDEX'])
      key: prefs.get(key),
  };
  final mottos = List<String>.from(data['mottos'] as List? ?? []);
  final nickname = data['nickname'] as String? ?? '';
  final signature = data['signature'] as String? ?? '';
  final avatar = data['avatarPath'] as String? ?? '';
  final next = previous.copyWith(
    backgroundImages: List<String>.from(
      data['backgroundImages'] as List? ?? [],
    ),
    sidebarImages: List<String>.from(data['sidebarImages'] as List? ?? []),
    mottos: mottos.isEmpty ? previous.mottos : mottos,
    nickname: nickname.isEmpty ? previous.nickname : nickname,
    signature: signature.isEmpty ? previous.signature : signature,
    avatarPath: avatar.isEmpty ? null : avatar,
    clearAvatar: avatar.isEmpty,
  );
  try {
    await service.saveSettings(next);
    final network = data['networkConfig'] as Map?;
    if (network != null) {
      for (final entry in {
        'apiKey': 'API_KEY',
        'hostList': 'PC_HOST_LIST',
      }.entries) {
        final value = network[entry.key]?.toString() ?? '';
        if (value.isNotEmpty) await prefs.setString(entry.value, value);
      }
      if (network['activeIndex'] != null) {
        await prefs.setInt(
          'PC_ACTIVE_INDEX',
          int.tryParse(network['activeIndex'].toString()) ?? 0,
        );
      }
    }
  } catch (_) {
    await service.saveSettings(previous);
    for (final entry in previousNetwork.entries) {
      final value = entry.value;
      if (value is String) {
        await prefs.setString(entry.key, value);
      } else if (value is int) {
        await prefs.setInt(entry.key, value);
      } else {
        await prefs.remove(entry.key);
      }
    }
    rethrow;
  }
}
