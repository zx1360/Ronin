import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/core/services/network/api_client.dart';

export 'sixty_news_providers.dart';
export 'sixty_utils_providers.dart';
export 'sixty_hot_providers.dart';
export 'sixty_entertainment_providers.dart';

part 'sixty_api_provider.g.dart';

// 60s API 基础客户端与通用类型
@riverpod
ApiClient sixtyApiClient(SixtyApiClientRef ref) {
  return ApiClient(baseUrl: 'https://60s.viki.moe');
}

typedef Json = Map<String, dynamic>;