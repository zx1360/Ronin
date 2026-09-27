import 'dart:io';

import 'package:flutter/material.dart';

class ComicImage extends StatelessWidget {
  final String path;
  final bool isLocal;
  final Map<String, String> httpHeaders;
  const ComicImage({super.key, required this.path, required this.isLocal, this.httpHeaders = const {}});

  @override
  Widget build(BuildContext context) {
    return isLocal?
    Image.file(
      File(path),
      width: double.infinity,
      fit: BoxFit.fitWidth,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: double.infinity,
          height: 64,
          color: Colors.black12,
          child: const Center(
            child: Icon(Icons.error, color: Colors.grey, size: 40),
          ),
        );
      },
    ):
    Image.network(
      path,
      headers: httpHeaders,
      width: double.infinity,
      fit: BoxFit.fitWidth,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: double.infinity,
          height: 64,
          color: Colors.black12,
          child: const Center(
            child: Icon(Icons.error, color: Colors.grey, size: 40),
          ),
        );
      },
    );
  }
}