import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BackHandler extends StatefulWidget {
  final Widget child;
  final bool Function()? onBack;

  const BackHandler({super.key, required this.child, this.onBack});

  static const _exitTimeout = Duration(seconds: 2);

  @override
  State<BackHandler> createState() => _BackHandlerState();
}

class _BackHandlerState extends State<BackHandler> {
  DateTime? _lastPressedTime;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;

        if (widget.onBack?.call() ?? false) {
          _lastPressedTime = null;
          return;
        }

        final now = DateTime.now();
        if (_lastPressedTime != null &&
            now.difference(_lastPressedTime!) <= BackHandler._exitTimeout) {
          await SystemChannels.platform.invokeMethod('SystemNavigator.pop');
          return;
        }

        _lastPressedTime = now;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('再按一次返回键退出应用'),
            duration: BackHandler._exitTimeout,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: widget.child,
    );
  }
}
