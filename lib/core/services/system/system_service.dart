import 'dart:io';

class SystemService {
  // 通知Android系统扫描文件，使其在相册中可见
  static Future<void> scanFile(String path) async {
    try {
      await Process.run('am', [
        'broadcast',
        '-a',
        'android.intent.action.MEDIA_SCANNER_SCAN_FILE',
        '-d',
        'file://$path',
      ]);
    } catch (e) {
      print('扫描文件失败: $e');
    }
  }
  
}