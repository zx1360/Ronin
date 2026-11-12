import 'dart:convert';
import 'dart:io';

import 'package:torrid/core/services/io/io_service.dart';

class GalleryStorageService {
  GalleryStorageService(this.libraryId);

  final Future<String?> Function() libraryId;

  Future<File> _file(String kind, String path) async {
    final id = await libraryId();
    if (id == null) throw StateError('请先连接服务端图库');
    final directory = base64Url.encode(utf8.encode(id));
    final normalized = path.replaceAll('\\', '/');
    final root = 'gallery/$directory/$kind';
    return IoService.offlineFile(
      normalized.isEmpty ? root : '$root/$normalized',
    );
  }

  Future<String> getLocalThumbPath(String path) async =>
      (await _file('Thumbs', path)).path;

  Future<String> getLocalPreviewPath(String path) async =>
      (await _file('Previews', path)).path;

  Future<File> saveThumbFile({
    required String serverPath,
    required List<int> bytes,
  }) async =>
      IoService.writeAtomically(await _file('Thumbs', serverPath), bytes);

  Future<File> savePreviewFile({
    required String serverPath,
    required List<int> bytes,
  }) async =>
      IoService.writeAtomically(await _file('Previews', serverPath), bytes);

  Future<File?> _ifPresent(File file) async =>
      await file.exists() && await file.length() > 0 ? file : null;

  Future<File?> getThumbFile(String path) async =>
      _ifPresent(await _file('Thumbs', path));

  Future<File?> getPreviewFile(String path) async =>
      _ifPresent(await _file('Previews', path));

  Future<GalleryStorageStats> getStorageStats() async {
    final directory = await IoService.offlineDirectory('gallery');
    var fileCount = 0;
    var totalBytes = 0;
    await for (final entry in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entry is File) {
        fileCount++;
        totalBytes += await entry.length();
      }
    }
    return GalleryStorageStats(fileCount: fileCount, totalBytes: totalBytes);
  }

  Future<void> clearAllFiles() => IoService.deleteOfflineDirectory('gallery');
}

class GalleryStorageStats {
  const GalleryStorageStats({
    required this.fileCount,
    required this.totalBytes,
  });

  final int fileCount;
  final int totalBytes;

  String get formattedSize {
    const kb = 1024;
    if (totalBytes < kb) return '$totalBytes B';
    if (totalBytes < kb * kb) {
      return '${(totalBytes / kb).toStringAsFixed(2)} KB';
    }
    if (totalBytes < kb * kb * kb) {
      return '${(totalBytes / (kb * kb)).toStringAsFixed(2)} MB';
    }
    return '${(totalBytes / (kb * kb * kb)).toStringAsFixed(2)} GB';
  }
}
