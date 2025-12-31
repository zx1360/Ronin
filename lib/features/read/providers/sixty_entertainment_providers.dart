import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/read/providers/sixty_client.dart';

// ---------------- 消遣娱乐 ----------------
final changyaAudioProvider = FutureProvider<Json>((ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get(
    '/v2/changya',
    queryParams: {'encoding': 'json'},
  );
  return (resp.data as Json)['data'] as Json;
});

final hitokotoProvider = FutureProvider<Json>((ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get(
    '/v2/hitokoto',
    queryParams: {'encoding': 'json'},
  );
  return (resp.data as Json)['data'] as Json;
});

final duanziProvider = FutureProvider<Json>((ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get(
    '/v2/duanzi',
    queryParams: {'encoding': 'json'},
  );
  return (resp.data as Json)['data'] as Json;
});

final fabingProvider = FutureProvider.family<Json, String?>((ref, name) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get(
    '/v2/fabing',
    queryParams: {
      if (name != null && name.isNotEmpty) 'name': name,
      'encoding': 'json',
    },
  );
  return (resp.data as Json)['data'] as Json;
});

final kfcCopyProvider = FutureProvider<Json>((ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get('/v2/kfc', queryParams: {'encoding': 'json'});
  return (resp.data as Json)['data'] as Json;
});

final dadJokeProvider = FutureProvider<Json>((ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get(
    '/v2/dad-joke',
    queryParams: {'encoding': 'json'},
  );
  return (resp.data as Json)['data'] as Json;
});
