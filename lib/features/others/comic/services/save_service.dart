import 'package:torrid/core/services/storage/public_storage_service.dart';

/// 漫画保存服务 - 使用统一的公共存储服务
class ComicSaverService {
  /// 翻页漫画的某页保存到外部公共空间
  static Future<bool> saveFlipImageToPublic(
    String privateImagePath,
    String filename,
  ) async {
    final result = await PublicStorageService.copyFile(
      subDir: PublicStorageService.dirComic,
      sourceFilePath: privateImagePath,
      fileName: filename.isEmpty ? null : filename,
    );
    return result != null;
  }

  /// 下拉漫画合并保存到外部公共空间
  static Future<bool> saveScrollImagesToPublic(
    List<String> imagePaths,
    String filename,
  ) async {
    return PublicStorageService.mergeAndSaveImages(
      subDir: PublicStorageService.dirComic,
      imagePaths: imagePaths,
      fileName: filename,
    );
  }
}
