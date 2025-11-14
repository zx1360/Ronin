import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';

part 'server_conn_provider.g.dart';

@Riverpod(keepAlive: true)
class ServerConnector extends _$ServerConnector {
  @override
  Map build() {
    return {
      "ceased": false,
      "connected": false,
      "isLoading": false,
    };
  }

  // 网络请求测试方法.
  Future<void> test() async {
    bool connected_ = false;
    final resp = await ref.read(fetcherProvider(path: "/util/test").future);
    if (resp != null && resp.statusCode == 200) {
      connected_ = true;
    }
    state = {...state, 'connected': connected_};
  }

  // 网络请求时切换为"加载中"
  // TODO: state加入"队列", 对于失败的重新入队直到['ceased']=True提示失败.
  Future<void> loadWithFunc(Function func) async {
    state = {...state, "isLoading": true};
    await func();
    state = {...state, "isLoading": false};
  }
}
