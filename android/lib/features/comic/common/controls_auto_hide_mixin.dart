import 'dart:async';
import 'package:flutter/widgets.dart';

mixin ControlsAutoHideMixin<T extends StatefulWidget> on State<T> {
  bool showControls = true;
  Timer? _controlsTimer;

  void initializeControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted || !showControls) return;
      setState(() {
        showControls = false;
      });
    });
  }

  void resetControlsTimer() {
    setState(() {
      showControls = true;
    });
    initializeControlsTimer();
  }

  void cancelControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = null;
  }

  @override
  void dispose() {
    cancelControlsTimer();
    super.dispose();
  }

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
