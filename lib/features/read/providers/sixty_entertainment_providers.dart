import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/read/providers/sixty_api_provider.dart';
part 'sixty_entertainment_providers.g.dart';

// ---------------- 消遣娱乐 ----------------
@riverpod
Future<Json> changyaAudio(ChangyaAudioRef ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get(
    '/v2/changya',
    queryParams: {'encoding': 'json'},
  );
  return (resp.data as Json)['data'] as Json;
}

@riverpod
Future<Json> hitokoto(HitokotoRef ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get(
    '/v2/hitokoto',
    queryParams: {'encoding': 'json'},
  );
  return (resp.data as Json)['data'] as Json;
}

@riverpod
Future<Json> duanzi(DuanziRef ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get(
    '/v2/duanzi',
    queryParams: {'encoding': 'json'},
  );
  return (resp.data as Json)['data'] as Json;
}

@riverpod
Future<Json> fabing(FabingRef ref, String? person) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get(
    '/v2/fabing',
    queryParams: {
      if (person != null && person.isNotEmpty) 'name': person,
      'encoding': 'json',
    },
  );
  return (resp.data as Json)['data'] as Json;
}

@riverpod
Future<Json> kfcCopy(KfcCopyRef ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get('/v2/kfc', queryParams: {'encoding': 'json'});
  return (resp.data as Json)['data'] as Json;
}

@riverpod
Future<Json> dadJoke(DadJokeRef ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get(
    '/v2/dad-joke',
    queryParams: {'encoding': 'json'},
  );
  return (resp.data as Json)['data'] as Json;
}
