import 'package:flutter/material.dart';

class GalleryPage extends StatelessWidget {
  const GalleryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("媒体管理"),),
      body: Center(
        child: Text("gallery库"),
      ),
    );
  }
}