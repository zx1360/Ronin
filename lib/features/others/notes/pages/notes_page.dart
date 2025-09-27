import 'package:flutter/material.dart';

class NotesPage extends StatelessWidget {
  const NotesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text("Notes\n并非传统意义的笔记, 广纳所有有意思的东西."),
      ),
    );
  }
}