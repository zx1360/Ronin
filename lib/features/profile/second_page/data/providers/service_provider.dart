import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'service_provider.g.dart';

class Cashier{
  
}

@riverpod
class DataService extends _$DataService{
  @override
  Cashier build(){
    return Cashier();
  }
}
