import 'package:file_picker/file_picker.dart';

class PathPickerService {
  /// 选择可执行文件；平台异常（原生弹窗失败等）按"未选择"处理，不抛到 UI 层。
  Future<String?> pickExecutable({String? initialDirectory}) async {
    try {
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
    } catch (_) {
      return null;
    }
  }
}
