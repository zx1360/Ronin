import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/providers/progress/progress.dart';

part 'progress_provider.g.dart';

@riverpod
class ProgressService extends _$ProgressService {
  @override
  Progress build() {
    return Progress.empty();
  }

  // 初始化进度对象
  void setProgress(Progress progress) {
    state = progress;
  }

  // 修改进度.
  void increaseProgress({
    required int current,
    required String currentMessage,
  }) {
    state = state.copyWith(current: current, currentMessage: currentMessage);
  }

  // 状态充值
  void resetStatus(){
    state=Progress.empty();
  }
}
