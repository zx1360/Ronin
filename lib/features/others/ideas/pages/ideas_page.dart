import 'package:flutter/material.dart';

class IdeasPage extends StatelessWidget {
  const IdeasPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text("idea\n记录天马行空的想法\n以及感悟\n或者时刻提醒以后的自己要记得的事."),
      ),
    );
  }
}