import 'dart:io';

import 'package:file_picker/file_picker.dart';

class PathPickerService {
  Future<String?> pickExecutable({String? initialDirectory}) async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: '选择可执行文件',
      initialDirectory: initialDirectory,
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: const <String>['exe'],
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    return result.files.single.path;
  }

  Future<String?> pickDirectory({String? initialDirectory}) {
    return FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择工作目录',
      initialDirectory: initialDirectory,
    );
  }

  Future<bool> executableExists(String path) async {
    return File(path).exists();
  }

  Future<bool> directoryExists(String path) async {
    return Directory(path).exists();
  }
}
