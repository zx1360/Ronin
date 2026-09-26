import 'dart:io';

import 'package:path/path.dart' as p;

/// 在资源管理器中打开并选中指定文件。
///
/// 与 CLI/后端的删除流程无关，纯本地查看：服务端与桌面端同机运行，
/// 因此把相对路径与 gallery 根目录拼成绝对路径即可。
class FileRevealService {
  /// 返回 null 表示已发起打开，否则为失败原因。
  static Future<String?> reveal(String absolutePath) async {
    if (absolutePath.trim().isEmpty) return '文件路径为空';
    final file = File(absolutePath);
    if (!await file.exists()) return '文件不存在: $absolutePath';

    try {
      // explorer 的 /select 参数必须与路径同处一个参数；explorer 自身会立即返回，
      // 因此不等待退出码（它总是非 0）。
      await Process.start(
        'explorer.exe',
        ['/select,${file.path}'],
        mode: ProcessStartMode.detached,
      );
      return null;
    } catch (e) {
      return '打开资源管理器失败: $e';
    }
  }

  /// 拼接 gallery 媒体文件的绝对路径。
  ///
  /// [mediaRoot] 为服务端返回的 `<GALLERY_DIR>/Media` 绝对路径，
  /// [filePath] 为库内的相对路径（可能混用两种分隔符）。
  static String absoluteMediaPath(String mediaRoot, String filePath) {
    final segments = filePath
        .split(RegExp(r'[/\\]'))
        .where((segment) => segment.isNotEmpty);
    return p.joinAll([mediaRoot, ...segments]);
  }
}
