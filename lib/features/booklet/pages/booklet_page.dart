import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:torrid/features/booklet/widgets/bottom_navbar/bottom_nav_bar.dart';
import 'package:torrid/features/booklet/pages/mission_page.dart';
import 'package:torrid/features/booklet/pages/routine_page.dart';

class BookletPage extends StatefulWidget {
  const BookletPage({super.key});

  @override
  State<BookletPage> createState() => _BookletPageState();
}

class _BookletPageState extends State<BookletPage> {
  // # 打卡页和挑战页之间的切换实现.
  int _curIndex = 0;
  final List<Widget Function()> _pages = [
    () => RoutinePage(),
    () => MissionPage(),
  ];
  final List<String> _pageTitles = ["日常打卡", "攻克难关"];
  void _switchIndex(int index) {
    setState(() {
      _curIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 顶部栏
      appBar: AppBar(
        title: Text(
          _pageTitles[_curIndex],
          style: const TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.yellow.shade200,
        elevation: 2,
        shadowColor: Colors.yellow,
        iconTheme: const IconThemeData(color: Colors.black87),
        actionsIconTheme: const IconThemeData(color: Colors.black87),
        bottom: null,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
      ),
      // 底部栏
      bottomNavigationBar: createBottomNavBar(_curIndex, _switchIndex),

      // 内容
      body: Center(child: _pages[_curIndex]()),
    );
  }
}
