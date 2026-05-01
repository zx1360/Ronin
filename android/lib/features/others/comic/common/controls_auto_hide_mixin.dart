import 'dart:async';
import 'package:flutter/widgets.dart';

/// 通用的操作栏自动隐藏混入，统一控制显隐与计时器生命周期
mixin ControlsAutoHideMixin<T extends StatefulWidget> on State<T> {
  bool showControls = true;
  late Timer _controlsTimer;
  final Duration closeBarDuration = const Duration(seconds: 4);

  void initializeControlsTimer() {
    _controlsTimer = Timer.periodic(closeBarDuration, (timer) {
      if (mounted && showControls) {
        setState(() {
          showControls = false;
        });
      }
    });
  }

  void resetControlsTimer() {
    _controlsTimer.cancel();
    setState(() {
      showControls = true;
    });
    initializeControlsTimer();
  }

  /// 仅取消，不销毁计时器实例（用于滑动开始时避免自动隐藏）
  void cancelControlsTimer() {
    _controlsTimer.cancel();
  }

  void disposeControlsTimer() {
    _controlsTimer.cancel();
  }

  /// 页面点击时切换操作栏显隐
  void handleTapToggle() {
    if (showControls) {
      _controlsTimer.cancel();
      setState(() {
        showControls = false;
      });
    } else {
      resetControlsTimer();
    }
  }
}
