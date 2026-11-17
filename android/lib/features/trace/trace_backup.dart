import 'package:torrid/core/services/network/api_client.dart';

import 'trace_data.dart';
import 'trace_store.dart';

Future<void> syncTraceBackup(
  TraceStore store,
  ApiClient client, {
  required void Function() checkConnection,
}) async {
  const path = '/API/user-data/trace/backup';
  if (client.baseUrl.isEmpty) throw const ApiException('请先配置后端连接');
  for (var attempt = 0; attempt < 2; attempt++) {
    final response = await client.get(path);
    if (response.statusCode != 200 || response.data is! Map<String, dynamic>) {
      throw ApiException('读取时迹备份失败（HTTP ${response.statusCode}）');
    }
    final data = response.data as Map<String, dynamic>;
    final revision = data['revision'];
    if (revision is! int || revision < 0 || !data.containsKey('snapshot')) {
      throw const FormatException('时迹备份修订号无效');
    }
    final remote = revision == 0 && data['snapshot'] == null
        ? TraceData([], [], [], [])
        : TraceData.fromJson(data['snapshot'] as Map<String, dynamic>);
    checkConnection();
    final snapshot = await store.mergeBackup(remote);
    if (snapshot == null) return;
    checkConnection();
    final saved = await client.putJson(
      path,
      data: {'revision': revision, 'snapshot': snapshot.toJson()},
    );
    if (saved.statusCode == 200 &&
        saved.data is Map &&
        saved.data['revision'] == revision + 1) {
      return;
    }
    if (saved.statusCode != 409) {
      throw ApiException('保存时迹备份失败（HTTP ${saved.statusCode}）');
    }
  }
  throw const ApiException('后端备份已更新，请重试同步');
}
