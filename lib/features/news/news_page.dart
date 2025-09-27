import 'package:flutter/material.dart';

class NewsPage extends StatelessWidget {
  const NewsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text("News\n每周科技快报, 新闻联播摘要, 资讯快报早知道."),
      ),
    );
  }
}