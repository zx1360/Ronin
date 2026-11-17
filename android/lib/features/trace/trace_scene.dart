const traceDefaultColor = '#547760';
const traceOtherSceneId = 'trace:other';
const traceOtherSceneName = '其他';

enum TraceSceneDeletion { keep, erase }

final _legacyPreset = RegExp(r'^00000000-0000-4000-8000-00000000000[0-4]$');
final _hexColor = RegExp(r'^#?[0-9a-fA-F]{6}$');

bool isTraceLegacyPreset(String id) => _legacyPreset.hasMatch(id);

String? traceColorHex(String text) {
  final value = text.trim();
  if (!_hexColor.hasMatch(value)) return null;
  return (value.startsWith('#') ? value : '#$value').toUpperCase();
}

String traceColorFromRgb(int rgb) =>
    '#${(rgb & 0xffffff).toRadixString(16).padLeft(6, '0').toUpperCase()}';
