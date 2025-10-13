import 'dart:io';

import 'package:image_picker/image_picker.dart';

class FilepickerService {
  final ImagePicker _picker = ImagePicker();

  Future<List<File>> pickImages({int maxImages = 5}) async {
    try {
      final pickedFiles = await _picker.pickMultiImage(limit: maxImages);
      if (pickedFiles.isEmpty) {
        return [];
      }
      return pickedFiles.map((file) => File(file.path)).toList();
    } catch (e) {
      throw Exception("文件选择器出错.");
    }
  }
}
