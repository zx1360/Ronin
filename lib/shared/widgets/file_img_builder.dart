import 'dart:io';

import 'package:flutter/material.dart';
import 'package:torrid/services/io/io_service.dart';

class FileImageBuilder extends StatelessWidget {
  final String relativeImagePath;
  final bool isOriginScale;
  const FileImageBuilder({
    super.key,
    required this.relativeImagePath,
    this.isOriginScale=false,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File?>(
      future: IoService.getImageFile(relativeImagePath),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasData) {
            // 是否原尺寸展示
            return isOriginScale?
            Image.file(
              snapshot.data!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 60,
                  height: 60,
                  color: Colors.yellow.shade200,
                  child: Icon(Icons.task, color: Colors.yellow.shade700),
                );
              },
            ):
            Image.file(
              snapshot.data!,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 60,
                  height: 60,
                  color: Colors.yellow.shade200,
                  child: Icon(Icons.task, color: Colors.yellow.shade700),
                );
              },
            );
          }
        }
        return Container(
          width: 60,
          height: 60,
          color: Colors.yellow.shade200,
          child: snapshot.connectionState == ConnectionState.waiting
              ? const CircularProgressIndicator(strokeWidth: 2)
              : Icon(Icons.task, color: Colors.yellow.shade700),
        );
      },
    );
  }
}
