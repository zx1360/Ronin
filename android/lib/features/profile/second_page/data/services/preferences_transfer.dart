import 'package:torrid/core/services/personalization/personalization_service.dart';
import 'package:torrid/core/services/storage/prefs_service.dart';

Map<String, dynamic> packPreferences() {
  final settings = PersonalizationService().getSettings();
  return {
    'backgroundImages': settings.backgroundImages,
    'sidebarImages': settings.sidebarImages,
    'mottos': settings.mottos,
    'nickname': settings.nickname,
    'signature': settings.signature,
    'avatarPath': settings.avatarPath ?? '',
  };
}

List<String> preferenceImagePaths(Map<String, dynamic> data) => [
  ...List<String>.from(data['backgroundImages'] as List? ?? []),
  ...List<String>.from(data['sidebarImages'] as List? ?? []),
  if ((data['avatarPath'] as String?)?.isNotEmpty == true)
    data['avatarPath'] as String,
];

Future<void> restorePreferences(Map<String, dynamic> data) {
  final next = AppSettings.fromJson(data);
  if (next.avatarPath?.isEmpty == true) next.avatarPath = null;
  return PersonalizationService().restoreSettings(next);
}
