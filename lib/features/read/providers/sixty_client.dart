import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/core/services/network/api_client.dart';
part 'sixty_client.g.dart';

// 60s API 基础客户端与通用类型
@riverpod
ApiClient sixtyApiClient(SixtyApiClientRef ref) {
  return ApiClient(baseUrl: 'https://60s.viki.moe');
}

typedef Json = Map<String, dynamic>;
