import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';
import 'package:torrid/core/services/network/transfer_service.dart';

part 'network_provider.g.dart';

/// 提供 [TransferService] 实例的 Provider
///
/// 依赖 [apiClientManagerProvider] 获取配置好的网络客户端
@riverpod
TransferService transferService(TransferServiceRef ref) {
  final apiClient = ref.watch(apiClientManagerProvider);
  return TransferService(apiClient: apiClient);
}

/// 从相对URL批量下载文件并保存到指定目录
///
/// [urls] - 相对路径列表（不含 `/static/` 前缀）
/// [relativeDir] - 保存目标的相对目录路径（相对于应用外部私有空间）
///
/// 特性：
/// - 保存前自动清空目标目录
/// - 使用并发下载提升性能（默认并发数 5）
/// - 通过 [TransferService] 实现，便于测试和复用
///
/// 使用示例：
/// ```dart
/// await ref.read(
///   saveFromRelativeUrlsProvider(
///     urls: ['path/to/image1.png', 'path/to/image2.jpg'],
///     relativeDir: 'img_storage/booklet',
///   ).future,
/// );
/// ```
@riverpod
Future<void> saveFromRelativeUrls(
  SaveFromRelativeUrlsRef ref, {
  required List<String> urls,
  required String relativeDir,
}) async {
  final transferService = ref.read(transferServiceProvider);

  await transferService.downloadAndSaveFiles(
    urls: urls,
    relativeDir: relativeDir,
  );
}
