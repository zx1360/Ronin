// 全局返回拦截器组件
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// TODO:我的法克, 只有页面栈底层的页面才是两次回退返回桌面, 其他的是回到前一个页面.
class BackHandler extends StatefulWidget {
  final Widget child;

  const BackHandler({
    super.key,
    required this.child,
  });
  
  static const _exitTimeout = Duration(seconds: 2);

  @override
  State<BackHandler> createState() => _BackHandlerState();
}

class _BackHandlerState extends State<BackHandler> {
  DateTime? _lastPressedTime;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // 控制是否允许系统默认的返回行为
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        // 如果已经完成了弹出，则不需要处理
        if (didPop) return;

        // 第二次点击，退出应用
        final now = DateTime.now();
        if (_lastPressedTime != null && 
            now.difference(_lastPressedTime!) <= BackHandler._exitTimeout) {
          await SystemChannels.platform.invokeMethod('SystemNavigator.pop');
          return;
        }

        // 第一次点击，显示提示
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