import 'package:flutter/material.dart';
import 'package:torrid/features/others/viewhub/comic/hub_comic_page.dart';

class ViewhubPage extends StatelessWidget {
  const ViewhubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Builder(builder: (context) => const HubComicPage()),
    );
  }
}