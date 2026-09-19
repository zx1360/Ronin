import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:northstar/core/providers/comix/comix_providers.dart';
import 'package:northstar/domain/comix/models/comix_models.dart';
import 'package:northstar/domain/ops/models/ops_settings.dart';
import 'package:northstar/infrastructure/comix/comix_api_client.dart';

/// 记录 `fetchTasks` 调用次数的假客户端。
///
/// 只实现任务轮询相关接口；任务列表由 [tasks] 控制，用于模拟"运行中 → 结束"。
class _FakeComixApi implements ComixApi {
  _FakeComixApi(this.tasks);

  List<ComixTask> tasks;
  int fetchTasksCalls = 0;

  @override
  void dispose() {}

  @override
  Future<List<ComixTask>> fetchTasks(OpsSettings settings) async {
    fetchTasksCalls++;
    return List<ComixTask>.from(tasks);
  }

  @override
  Future<ComixTask> fetchTask(OpsSettings settings, String taskId) async {
    return tasks.firstWhere((t) => t.id == taskId);
  }

  @override
  Future<String> startTask(
    OpsSettings settings,
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    return 't-new';
  }

  @override
  Future<void> stopTask(OpsSettings settings, String taskId) async {}

  @override
  Future<Map<String, dynamic>> deleteComic(
    OpsSettings settings,
    int comicId, {
    bool keepFiles = false,
  }) async {
    return const <String, dynamic>{};
  }

  @override
  Future<void> updateComicMeta(
    OpsSettings settings,
    int comicId,
    Map<String, dynamic> body,
  ) async {}

  @override
  Future<List<ComixComic>> fetchComics(OpsSettings settings) async => const [];

  @override
  Future<List<ComixChapter>> fetchChapters(
    OpsSettings settings,
    int comicId,
  ) async => const [];

  @override
  Future<List<Map<String, dynamic>>> downloadUrls(
    OpsSettings settings,
    List<String> urls, {
    int? latest,
  }) async => const [];
}

ComixTask _task(String id, ComixTaskStatus status) {
  return ComixTask(
    id: id,
    name: 'task $id',
    command: 'download',
    status: status,
    pid: 1,
  );
}

void main() {
  setUp(() => ComixBoardNotifier.pollInterval = const Duration(milliseconds: 120));

  ProviderContainer containerWith(_FakeComixApi api) {
    final container = ProviderContainer(
      overrides: [comixApiClientProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('无任务时不发起任何轮询请求', () async {
    final api = _FakeComixApi([]);
    final container = containerWith(api);

    container.read(comixBoardProvider.notifier).setPageActive(true);
    await container.read(comixBoardProvider.notifier).refresh();
    expect(api.fetchTasksCalls, 1);

    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(api.fetchTasksCalls, 1, reason: '空闲时不应持续请求 /API/comix/tasks');
  });

  test('任务全部结束后停止轮询', () async {
    final api = _FakeComixApi([_task('t1', ComixTaskStatus.running)]);
    final container = containerWith(api);

    container.read(comixBoardProvider.notifier).setPageActive(true);
    await container.read(comixBoardProvider.notifier).refresh();

    await Future<void>.delayed(const Duration(milliseconds: 400));
    final duringRunning = api.fetchTasksCalls;
    expect(duringRunning, greaterThan(1), reason: '运行中应持续轮询');

    // 任务结束：轮询在本轮之后应停止
    api.tasks = [_task('t1', ComixTaskStatus.finished)];
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final settled = api.fetchTasksCalls;

    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(api.fetchTasksCalls, settled, reason: '任务结束后应停止轮询');
  });

  test('页面离开后停止轮询', () async {
    final api = _FakeComixApi([_task('t1', ComixTaskStatus.running)]);
    final container = containerWith(api);

    final notifier = container.read(comixBoardProvider.notifier);
    notifier.setPageActive(true);
    await notifier.refresh();
    await Future<void>.delayed(const Duration(milliseconds: 300));

    notifier.setPageActive(false);
    final afterLeaving = api.fetchTasksCalls;
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(api.fetchTasksCalls, afterLeaving, reason: '页面不可见时不应继续轮询');
  });

  test('提交后始终不出现的任务不会造成无限轮询', () async {
    // 服务端始终返回空列表：任务像是被裁剪/吞掉了
    final api = _FakeComixApi([]);
    final container = containerWith(api);
    final notifier = container.read(comixBoardProvider.notifier);

    notifier.setPageActive(true);
    await notifier.startTask('download', {'comic_id': 1});
    await Future<void>.delayed(const Duration(milliseconds: 1200));

    final afterGrace = api.fetchTasksCalls;
    await Future<void>.delayed(const Duration(milliseconds: 800));
    expect(api.fetchTasksCalls, afterGrace, reason: '超出宽限轮次后应停止轮询');
  });
}
