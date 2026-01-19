import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'profile_notifier_provider.g.dart';

@riverpod
class ProfileServer extends _$ProfileServer {
  @override
  Map build() {
    return {"allow_notify":false};
  }
 
}
