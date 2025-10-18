import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/services/network/apiclient_handler.dart';

part 'notifier_provider.g.dart';

@riverpod
class Server extends _$Server{
  @override
  Map build(){
    return {"connected": false};
  }

  // 网络请求测试方法.
  Future<void> testNetwork()async{
    print("__1");
    bool connected_ = false;
    final resp = await ApiclientHandler.fetch(path: "/util/test");
    if(resp!=null && resp.statusCode==200){
      connected_ = true;
    }
    state = {...state, 'connected':connected_};
  }

  
}