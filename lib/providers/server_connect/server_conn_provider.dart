import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';
import 'package:torrid/services/storage/prefs_service.dart';

part 'server_conn_provider.g.dart';

@Riverpod(keepAlive: true)
class ServerConnector extends _$ServerConnector {
  @override
  Map build() {
    return {
      "ceased": false,
      "connected": false,
      "isLoading": false,
      "host_": "115.190.232.188",
      "port_": "8080",
      "host": "",
      "port": "",
    };
  }

  // TODO: 之后有了NAS使用家里的公网ip+DDNS, 省去"IP_"这一中间人.
  // 请求云服务器获取PC网络地址.
  Future<void> getPcAddr() async {
    final resp = await ref.read(fetcherProvider(path: "/get-pc-addr").future);
    if (resp != null && resp.statusCode == 200) {
      print("__get-pc-addr");
      print(resp.data);
      if (resp.data['message'] == "OK") {
        print("OK");
        state = {...state, "host": resp.data['ip'], "port": resp.data['port']};
        ref.read(apiClientManagerProvider.notifier).switchToPCServer();
        ref.invalidate(fetcherProvider);
      } else {
        // PC端服务未启动.
      }
    } else {
      state = {...state, "connected": false};
    }
  }

  // 网络请求测试方法.
  Future<void> test() async {
    bool connected_ = false;
    final resp = await ref.read(fetcherProvider(path: "/api/test").future);
    print("__test");
    print(resp?.data);
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
