import 'package:flutter/material.dart';
import 'package:torrid/features/booklet/pages/routine_page.dart';

class BookletPage extends StatelessWidget {
  const BookletPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 顶部栏
      appBar: AppBar(
        title: Text(
          "日常打卡",
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
      ),

      // 内容
      body: Center(child: RoutinePage()),
    );
  }
}