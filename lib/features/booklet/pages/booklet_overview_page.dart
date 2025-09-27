import 'package:flutter/material.dart';
import 'package:torrid/features/booklet/widgets/bottom_nav_bar.dart';
import 'package:torrid/features/booklet/pages/mission_overview.dart';
import 'package:torrid/features/booklet/pages/routine_overview.dart';

class OverviewPage extends StatefulWidget {
  const OverviewPage({super.key});

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  // # 打卡页和挑战页之间的切换实现.
  int _curIndex = 0;
  final List<Widget Function()> _pages = [
    () => RoutineOverviewPage(),
    () => MissionOverViewPage(),
  ];
  void _switchIndex(int index) {
    setState(() {
      _curIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 底部栏
      bottomNavigationBar: createBottomNavBar(_curIndex, _switchIndex),

      // 内容
      body: Center(child: _pages[_curIndex]()),
    );
  }
}
