import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';

part 'server_conn_provider.g.dart';

@Riverpod(keepAlive: true)
class ServerConnector extends _$ServerConnector {
  @override
  Map build() {
    return {"connected": false, "isLoading": false};
  }

  // 网络请求测试方法.
  Future<void> test() async {
    bool connected_ = false;
    final resp = await ref.read(fetcherProvider(path: "/get-pc-addr").future);
    print(resp?.data);
      print(resp?.statusCode);
    if (resp != null && resp.statusCode == 200) {
      connected_ = true;
      print(resp.data);
      print(resp.statusCode);

      // final prefs = PrefsService().prefs;
      // final pcIp = prefs.getString("PC_IP");
      // final pcPort = prefs.getString("PC_PORT");
      // ref.invalidate(apiClientManagerProvider);
    }
    state = {...state, 'connected': connected_};
  }

  // 网络请求时切换为"加载中"
  Future<void> loadWithFunc(Function func) async {
    state = {...state, "isLoading": true};
    await func();
    state = {...state, "isLoading": false};
  }
}
