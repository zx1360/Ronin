import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'status_provider.g.dart';


@riverpod
class LoadingState extends _$LoadingState{
  @override
  bool build(){
    return false;
  }

}