import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as path;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/core/services/io/io_service.dart';
import 'package:torrid/features/read/providers/sixty_api_provider.dart';
import 'package:torrid/core/services/storage/hive_service.dart';
import 'package:torrid/features/read/models/changya/changya_user.dart';
import 'package:torrid/features/read/models/changya/changya_song.dart';
import 'package:torrid/features/read/models/changya/changya_audio.dart';
import 'package:torrid/features/read/models/changya/changya_record.dart';

// 保存“随机唱歌音频”的数据与文件到本地，并返回替换后的本地化数据（类型化）
final saveChangyaLocalProvider = FutureProvider.family<ChangyaRecord, Json>((ref, data) async {
  final json = Map<String, dynamic>.from(data);
  final userJson = (json['user'] as Map?)?.cast<String, dynamic>() ?? {};
  final songJson = (json['song'] as Map?)?.cast<String, dynamic>() ?? {};
  final audioJson = (json['audio'] as Map?)?.cast<String, dynamic>() ?? {};

  // 基目录: /changya/
  final baseRel = '/changya';
  await IoService.ensureDirExists('$baseRel/avatars');
  await IoService.ensureDirExists('$baseRel/audios');

  final dio = Dio(BaseOptions(responseType: ResponseType.bytes, followRedirects: true));

  // 用 publish_at 作为文件基名，若缺失则使用当前时间戳
    final publishAt = (audioJson['publish_at'] is int)
      ? audioJson['publish_at'] as int
      : DateTime.now().millisecondsSinceEpoch;
  final baseName = publishAt.toString();

  // 下载头像
  final avatarUrl = (userJson['avatar_url'] ?? '').toString();
  if (avatarUrl.isNotEmpty) {
    final ext = _extFromUrl(avatarUrl, fallback: '.jpg');
    final avatarRel = '$baseRel/avatars/$baseName$ext';
    await _downloadToRelative(dio: dio, url: avatarUrl, relativePath: avatarRel);
    userJson['avatar_url'] = avatarRel; // 替换为本地相对路径
  }

  // 下载音频
  final audioUrl = (audioJson['url'] ?? '').toString();
  if (audioUrl.isNotEmpty) {
    final ext = _extFromUrl(audioUrl, fallback: '.mp3');
    final audioRel = '$baseRel/audios/$baseName$ext';
    await _downloadToRelative(dio: dio, url: audioUrl, relativePath: audioRel);
    audioJson['url'] = audioRel; // 替换为本地相对路径
  }

  final user = ChangyaUser(
    nickname: userJson['nickname'] as String?,
    gender: userJson['gender'] as String?,
    avatarUrl: userJson['avatar_url'] as String?,
  );
  final song = ChangyaSong(
    name: songJson['name'] as String?,
    singer: songJson['singer'] as String?,
    lyrics: (songJson['lyrics'] is List)
        ? (songJson['lyrics'] as List).map((e) => e.toString()).toList()
        : const [],
  );
  final audio = ChangyaAudio(
    url: audioJson['url']?.toString(),
    duration: (audioJson['duration'] is int) ? audioJson['duration'] as int : int.tryParse('${audioJson['duration']}'),
    likeCount: (audioJson['like_count'] is int) ? audioJson['like_count'] as int : int.tryParse('${audioJson['like_count']}'),
    link: audioJson['link']?.toString(),
    publish: audioJson['publish']?.toString(),
    publishAt: publishAt,
  );
  final record = ChangyaRecord(id: baseName, user: user, song: song, audio: audio);

  final box = Hive.box<ChangyaRecord>(HiveService.changyaBoxName);
  await box.put(baseName, record);
  return record;
});

// 列出所有本地记录（按时间倒序）
final listChangyaLocalProvider = FutureProvider<List<ChangyaRecord>>((ref) async {
  final box = Hive.box<ChangyaRecord>(HiveService.changyaBoxName);
  final list = box.values.toList();
  list.sort((a, b) => (b.audio?.publishAt ?? 0).compareTo(a.audio?.publishAt ?? 0));
  return list;
});

// 最新本地记录
final latestChangyaLocalProvider = FutureProvider<ChangyaRecord?>((ref) async {
  final list = await ref.watch(listChangyaLocalProvider.future);
  return list.isNotEmpty ? list.first : null;
});

// 删除指定记录（含文件）
final deleteChangyaLocalProvider = FutureProvider.family<void, ChangyaRecord>((ref, record) async {
  final box = Hive.box<ChangyaRecord>(HiveService.changyaBoxName);
  // 删除头像与音频文件
  final avatarRel = record.user?.avatarUrl ?? '';
  final audioRel = record.audio?.url ?? '';
  final base = await IoService.externalStorageDir;
  for (final rel in [avatarRel, audioRel]) {
    if (rel.isNotEmpty && rel.startsWith('/')) {
      final full = path.join(base.path, rel.replaceFirst('/', ''));
      final f = File(full);
      if (await f.exists()) {
        await f.delete();
      }
    }
  }
  await box.delete(record.id);
});

String _extFromUrl(String url, {required String fallback}) {
  try {
    final uri = Uri.parse(url);
    final seg = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
    final ext = path.extension(seg);
    return ext.isNotEmpty ? ext : fallback;
  } catch (_) {
    return fallback;
  }
}

Future<File> _downloadToRelative({
  required Dio dio,
  required String url,
  required String relativePath,
}) async {
  // 归一化相对路径: 去掉开头'/'再 join
  final rel = relativePath.startsWith('/') ? relativePath.substring(1) : relativePath;
  final base = await IoService.externalStorageDir;
  final fullPath = path.join(base.path, rel);
  final file = File(fullPath);
  await file.create(recursive: true);
  final resp = await dio.get<List<int>>(url);
  final bytes = Uint8List.fromList(resp.data ?? []);
  await file.writeAsBytes(bytes);
  return file;
}
