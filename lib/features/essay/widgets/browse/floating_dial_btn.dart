import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:torrid/features/essay/pages/essay_write_page.dart';

class FloatingDialBtn extends StatelessWidget {
  const FloatingDialBtn({super.key});

  @override
  Widget build(BuildContext context) {
    return SpeedDial(
      icon: Icons.more_horiz,
      activeIcon: Icons.close,
      backgroundColor: Colors.blue,
      direction: SpeedDialDirection.up,
      children: [
        SpeedDialChild(
          child: const Icon(Icons.edit),
          // label: "写文章",
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const EssayWritePage()),
          ),
        ),
        // TODO: 目前的页面结构常规无法实现下面两个效果.
        // TODO: 之后试试riverpod实现,也理解理解GlobalKey实现的原理.
        SpeedDialChild(
          child: const Icon(Icons.refresh),
          // label: "刷新",
          onTap: () => {},
        ),
        SpeedDialChild(
          child: const Icon(Icons.rocket),
          // label: "回到顶部",
          onTap: () => {},
        ),
      ],
    );
  }
}
