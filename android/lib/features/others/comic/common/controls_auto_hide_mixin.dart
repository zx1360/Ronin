import 'dart:async';
import 'package:flutter/widgets.dart';

/// 通用的操作栏自动隐藏混入，统一控制显隐与计时器生命周期
mixin ControlsAutoHideMixin<T extends StatefulWidget> on State<T> {
  bool showControls = true;
  Timer? _controlsTimer;
  final Duration closeBarDuration = const Duration(seconds: 4);

  /// 启动自动隐藏计时；重复调用不会叠加计时器
  void initializeControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(closeBarDuration, () {
      if (!mounted || !showControls) return;
      setState(() {
        showControls = false;
      });
    });
  }

  void resetControlsTimer() {
    _controlsTimer?.cancel();
    setState(() {
      showControls = true;
    });
    initializeControlsTimer();
  }

  /// 仅取消，不销毁计时器实例（用于滑动开始时避免自动隐藏）
  void cancelControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = null;
  }

  void disposeControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = null;
  }

  /// 页面点击时切换操作栏显隐
  void handleTapToggle() {
    if (showControls) {
      cancelControlsTimer();
      setState(() {
        showControls = false;
      });
    } else {
      resetControlsTimer();
    }
  }
}
