import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'profile_notifier_provider.g.dart';

@riverpod
class ProfileServer extends _$ProfileServer {
  @override
  Map build() {
    return {"allow_notify":false};
  }
 
  // TODO: build中调用异步函数, 返回空字典. 监听.then()再次使用state通知.
}
