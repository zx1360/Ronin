import 'package:flutter/material.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '库存页',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
    );
  }
}