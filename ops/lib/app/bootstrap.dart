import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:northstar/core/providers/ops/core_services_provider.dart';

/// 应用启动引导：先创建 provider 容器，并把 provider 需要**同步**读取的
/// 持久化数据预载完成，再把同一个容器交给 `runApp`。
///
/// 若省掉这一步（让 provider 自己在 build 里异步补载），首个网络请求会带着
/// 默认配置发出（连错端口/协议），表现为启动后仪表盘请求失败、手动刷新才正常。
Future<ProviderContainer> bootstrap() async {
  final container = ProviderContainer();
  try {
    await container.read(opsPersistenceRepositoryProvider).ensureLoaded();
  } catch (_) {
    // 预载失败时以默认配置启动，不影响应用可用性（设置页仍可修改并落盘）。
  }
  return container;
}
