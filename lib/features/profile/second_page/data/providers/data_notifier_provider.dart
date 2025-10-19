import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';

part 'data_notifier_provider.g.dart';

// 数据传输页的响应式数据.
@riverpod
class DataServer extends _$DataServer {
  @override
  Map build() {
    return {"connected": false};
  }

  // 网络请求测试方法.
  Future<void> testNetwork() async {
    print("__1");
    bool connected_ = false;
    final resp = await ref.read(fetcherProvider(path: "/util/test").future);
    if (resp != null && resp.statusCode == 200) {
      connected_ = true;
    }
    state = {...state, 'connected': connected_};
  }
}
