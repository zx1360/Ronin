import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:torrid/app/theme/theme_book.dart';

/// 可展开的浮动操作按钮
/// 点击后展开多个选项
class ExpandableFab extends StatefulWidget {
  final double distance;
  final List<FabAction> actions;

  const ExpandableFab({
    super.key,
    this.distance = 80,
    required this.actions,
  });

  @override
  State<ExpandableFab> createState() => _ExpandableFabState();
}

class _ExpandableFabState extends State<ExpandableFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _expandAnimation;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      value: 0.0,
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
      parent: _controller,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  void _close() {
    if (_isOpen) {
      setState(() {
        _isOpen = false;
        _controller.reverse();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        alignment: Alignment.bottomRight,
        clipBehavior: Clip.none,
        children: [
          // 半透明遮罩（点击关闭）
          if (_isOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _close,
                child: Container(
                  color: Colors.black.withAlpha(30),
                ),
              ),
            ),
          // 展开的按钮
          ..._buildExpandingActionButtons(),
          // 主按钮
          _buildMainButton(),
        ],
      ),
    );
  }

  List<Widget> _buildExpandingActionButtons() {
    final children = <Widget>[];
    final count = widget.actions.length;
    
    for (int i = 0; i < count; i++) {
      final action = widget.actions[i];
      children.add(
        _ExpandingActionButton(
          directionInDegrees: 90.0, // 向上展开
          maxDistance: widget.distance * (count - i),
          progress: _expandAnimation,
          child: _ActionButton(
            icon: action.icon,
            label: action.label,
            onPressed: () {
              _close();
              action.onPressed();
            },
          ),
        ),
      );
    }
    return children;
  }

  Widget _buildMainButton() {
    return AnimatedBuilder(
      animation: _expandAnimation,
      builder: (context, child) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: FloatingActionButton(
            elevation: 6,
            highlightElevation: 10,
            backgroundColor: AppTheme.primary,
            foregroundColor: AppTheme.onPrimary,
            onPressed: _toggle,
            child: AnimatedRotation(
              duration: const Duration(milliseconds: 200),
              turns: _isOpen ? 0.125 : 0, // 旋转45度
              child: const Icon(Icons.add, size: 28),
            ),
          ),
        );
      },
    );
  }
}

/// 展开动画按钮
class _ExpandingActionButton extends StatelessWidget {
  final double directionInDegrees;
  final double maxDistance;
  final Animation<double> progress;
  final Widget child;

  const _ExpandingActionButton({
    required this.directionInDegrees,
    required this.maxDistance,
    required this.progress,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (context, child) {
        final offset = Offset.fromDirection(
          directionInDegrees * (math.pi / 180.0),
          progress.value * maxDistance,
        );
        return Positioned(
          right: 16 + 4, // FAB padding + 小按钮偏移
          bottom: 16 + 56 + offset.dy.abs(), // FAB padding + FAB size + 动画偏移
          child: Transform.scale(
            scale: progress.value,
            child: Opacity(
              opacity: progress.value,
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

/// 操作按钮（带标签）
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(30),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        const SizedBox(width: 8),
        FloatingActionButton.small(
          heroTag: label,
          elevation: 4,
          backgroundColor: AppTheme.primary,
          foregroundColor: AppTheme.onPrimary,
          onPressed: onPressed,
          child: Icon(icon, size: 20),
        ),
      ],
    );
  }
}

/// FAB 操作配置
class FabAction {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const FabAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });
}
