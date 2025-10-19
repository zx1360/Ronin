import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'service_provider.g.dart';

// 实际提供相关操作的notifier.
class Cashier{
  
}

@riverpod
class DataService extends _$DataService{
  @override
  Cashier build(){
    return Cashier();
  }
}
