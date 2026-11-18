import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/providers/progress/progress.dart';

part 'progress_provider.g.dart';

@riverpod
class ProgressService extends _$ProgressService {
  @override
  Progress build() {
    return Progress.empty();
  }

  void setProgress(Progress progress) {
    state = progress;
  }

  void increaseProgress({
    required int current,
    required String currentMessage,
  }) {
    state = state.copyWith(current: current, currentMessage: currentMessage);
  }

  void resetStatus(){
    state=Progress.empty();
  }
}
