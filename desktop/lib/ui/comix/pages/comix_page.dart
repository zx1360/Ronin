import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:northstar/application/comix/providers/comix_providers.dart';
import 'package:northstar/application/ops/providers/ops_settings_provider.dart';
import 'package:northstar/app/theme.dart';
import 'package:northstar/domain/comix/models/comix_models.dart';
import 'package:northstar/shared/widgets/heading/heading.dart';
import 'package:northstar/ui/comix/widgets/comix_dialogs.dart';

/// 漫画爬虫管理页：通过本地 HTTP 向 Monarch 发送指令，
/// 由 Go 端任务引擎管理 comix 爬虫的生命周期（搜索/添加/下载/追更/删除/清理）。
class ComixPage extends ConsumerStatefulWidget {
  const ComixPage({super.key});

  @override
  ConsumerState<ComixPage> createState() => _ComixPageState();
}

class _ComixPageState extends ConsumerState<ComixPage> {
  final _searchController = TextEditingController();
  String? _siteFilter;
  String _searchKeyword = '';
  String? _searchTaskId;
  bool _searching = false;
  String? _searchError;
  List<ComixCandidate> _candidates = const [];
  final Set<String> _runningTaskIds = <String>{};
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _onPollTick(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(comixBoardProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // 轮询：任务运行期间刷新面板；任务结束刷新漫画列表；搜索任务结束取回候选
  // -------------------------------------------------------------------------

  Future<void> _onPollTick() async {
    final board = ref.read(comixBoardProvider);
    final runningNow = board.tasks
        .where((t) => t.isRunning)
        .map((t) => t.id)
        .toSet();
    final finishedNow = _runningTaskIds.difference(runningNow);
    final hadRunning = _runningTaskIds.isNotEmpty;
    _runningTaskIds
      ..clear()
      ..addAll(runningNow);

    if (board.hasRunningTasks || hadRunning) {
      await ref.read(comixBoardProvider.notifier).refresh();
    }
    if (finishedNow.isNotEmpty) {
      ref.invalidate(comixComicsProvider);
    }
    await _collectSearchResult();
  }

  Future<void> _collectSearchResult() async {
    final taskId = _searchTaskId;
    if (taskId == null) return;
    final board = ref.read(comixBoardProvider);
    final task = _firstWhereOrNull(board.tasks, (t) => t.id == taskId);
    if (task != null && task.isRunning) return;

    _searchTaskId = null;
    try {
      final settings = ref.read(opsSettingsControllerProvider);
      final client = ref.read(comixApiClientProvider);
      final detail = await client.fetchTask(settings, taskId);
      final result = detail.result;
      if (!mounted) return;
      setState(() {
        _searching = false;
        if (result != null && result['ok'] == true) {
          final data = result['data'];
          final list = data is Map<String, dynamic> ? data['candidates'] : null;
          _candidates = list is List
              ? list
                    .whereType<Map<String, dynamic>>()
                    .map(ComixCandidate.fromJson)
                    .toList()
              : const [];
          _searchError = null;
        } else {
          _candidates = const [];
          _searchError = (result?['error'] as String?) ?? detail.error ?? '搜索失败';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _candidates = const [];
        _searchError = e.toString();
      });
    }
  }

  // -------------------------------------------------------------------------
  // 操作
  // -------------------------------------------------------------------------

  Future<void> _doSearch() async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) {
      _snack('请输入漫画名称');
      return;
    }
    setState(() {
      _searchKeyword = keyword;
      _searching = true;
      _searchError = null;
      _candidates = const [];
    });
    try {
      final taskId = await ref
          .read(comixBoardProvider.notifier)
          .startTask('search', {'name': keyword});
      _searchTaskId = taskId;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _searchError = e.toString();
      });
    }
  }

  Future<void> _addCandidate(ComixCandidate candidate, int index) async {
    final options = await showAddComicDialog(context, candidate);
    if (options == null) return;
    try {
      // add-url：直接按详情 URL 添加，避免 add 重新搜索导致候选顺序漂移
      await ref.read(comixBoardProvider.notifier).startTask(
            'add-url',
            options.toBody(candidate),
          );
      ref.invalidate(comixComicsProvider);
      _snack('已提交添加任务：${candidate.title}');
    } catch (e) {
      _snack('提交添加失败: $e');
    }
  }

  Future<void> _downloadComic(ComixComic comic) async {
    final options = await showDownloadDialog(context, comic);
    if (options == null) return;
    try {
      await ref.read(comixBoardProvider.notifier).startTask(
            'download',
            options.toBody(comic.comicId),
          );
      _snack('已提交下载任务：${comic.title}');
    } catch (e) {
      _snack('提交下载失败: $e');
    }
  }

  Future<void> _updateCheck({int? comicId, String? title, bool all = false}) async {
    final options = await showUpdateCheckDialog(
      context,
      comicTitle: title,
      all: all,
    );
    if (options == null) return;
    try {
      await ref.read(comixBoardProvider.notifier).startTask(
            'update-check',
            options.toBody(comicId: comicId, all: all),
          );
      _snack(all ? '已提交全站追更检查' : '已提交追更检查：$title');
    } catch (e) {
      _snack('提交追更检查失败: $e');
    }
  }

  Future<void> _deleteComic(ComixComic comic) async {
    final options = await showDeleteComicDialog(context, comic);
    if (options == null) return;
    try {
      await ref.read(comixBoardProvider.notifier).startTask(
            'delete',
            options.toBody(comic.comicId),
          );
      ref.invalidate(comixComicsProvider);
      _snack('已提交删除任务：${comic.title}');
    } catch (e) {
      _snack('提交删除失败: $e');
    }
  }

  Future<void> _clean() async {
    try {
      await ref.read(comixBoardProvider.notifier).startTask('clean', {});
      _snack('已提交孤儿回收任务');
    } catch (e) {
      _snack('提交清理失败: $e');
    }
  }

  Future<void> _showChapters(ComixComic comic) async {
    try {
      final settings = ref.read(opsSettingsControllerProvider);
      final client = ref.read(comixApiClientProvider);
      final chapters = await client.fetchChapters(settings, comic.comicId);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => _ChaptersDialog(comic: comic, chapters: chapters),
      );
    } catch (e) {
      _snack('加载章节失败: $e');
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // -------------------------------------------------------------------------
  // UI
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(comixConfigProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Heading(title: '漫画爬虫'),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimens.paddingL),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildConfigBar(config),
                const SizedBox(height: AppDimens.spacingL),
                _buildSearchCard(),
                const SizedBox(height: AppDimens.spacingL),
                _buildToolbar(),
                const SizedBox(height: AppDimens.spacingL),
                _buildComicList(),
                const SizedBox(height: AppDimens.spacingL),
                _TaskPanel(onStop: _stopTask),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfigBar(AsyncValue<ComixConfig> config) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.paddingM,
          vertical: AppDimens.paddingS,
        ),
        child: config.when(
          data: (cfg) {
            final ok = cfg.available;
            return Row(
              children: [
                _StatusChip(
                  ok: ok,
                  label: ok ? 'comix 可用' : 'comix 不可用',
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    ok
                        ? 'python: ${cfg.python}   根目录: ${cfg.root}'
                        : '${cfg.message}（请在 backend/.env 中配置 COMIX_PYTHON / COMIX_ROOT）',
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: '刷新',
                  onPressed: () {
                    ref.invalidate(comixConfigProvider);
                    ref.invalidate(comixSitesProvider);
                    ref.invalidate(comixComicsProvider);
                    ref.read(comixBoardProvider.notifier).refresh();
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            );
          },
          loading: () => const Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 8),
              Text('加载 comix 配置...'),
            ],
          ),
          error: (e, _) => Text(
            'comix 配置加载失败: $e',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchCard() {
    final sites = ref.watch(comixSitesProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('搜索添加', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppDimens.spacingM),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: '漫画名称',
                      hintText: '如：海贼王',
                    ),
                    onSubmitted: (_) => _doSearch(),
                  ),
                ),
                const SizedBox(width: AppDimens.spacingM),
                SizedBox(
                  width: 220,
                  child: sites.when(
                    data: (list) => DropdownButtonFormField<String>(
                      initialValue: _siteFilter,
                      decoration: const InputDecoration(labelText: '站点'),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('全部站点'),
                        ),
                        for (final site in list)
                          DropdownMenuItem<String>(
                            value: site.code,
                            child: Text('${site.name} (${site.code})'),
                          ),
                      ],
                      onChanged: (v) => setState(() => _siteFilter = v),
                    ),
                    loading: () => const SizedBox(
                      height: 56,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => Text('站点加载失败: $e'),
                  ),
                ),
                const SizedBox(width: AppDimens.spacingM),
                ElevatedButton.icon(
                  onPressed: _searching ? null : _doSearch,
                  icon: _searching
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search_rounded),
                  label: Text(_searching ? '搜索中...' : '搜索'),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.spacingM),
            if (_searchError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '搜索失败: $_searchError',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (_candidates.isNotEmpty) ...[
              const Divider(height: 1),
              const SizedBox(height: AppDimens.spacingS),
              Text(
                '「$_searchKeyword」候选 ${_candidates.length} 个（点击添加）',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppDimens.spacingS),
              for (var i = 0; i < _candidates.length; i++)
                _CandidateTile(
                  candidate: _candidates[i],
                  index: i,
                  onAdd: () => _addCandidate(_candidates[i], i),
                ),
            ] else if (!_searching && _searchError == null)
              Text(
                '输入名称搜索，候选可跨站对比后选择添加',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.paddingM,
          vertical: AppDimens.paddingS,
        ),
        child: Wrap(
          spacing: AppDimens.spacingM,
          runSpacing: AppDimens.spacingS,
          children: [
            ElevatedButton.icon(
              onPressed: () => _updateCheck(all: true),
              icon: const Icon(Icons.update_rounded, size: 18),
              label: const Text('全站追更检查'),
            ),
            OutlinedButton.icon(
              onPressed: _clean,
              icon: const Icon(Icons.cleaning_services_outlined, size: 18),
              label: const Text('孤儿回收 clean'),
            ),
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(comixComicsProvider),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('刷新漫画列表'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComicList() {
    final comics = ref.watch(comixComicsProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('已登记漫画', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppDimens.spacingS),
            comics.when(
              data: (list) {
                if (list.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(AppDimens.paddingL),
                    child: Center(child: Text('暂无已登记漫画')),
                  );
                }
                return SizedBox(
                  height: 360,
                  child: ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final comic = list[index];
                      return _ComicTile(
                        comic: comic,
                        onDownload: () => _downloadComic(comic),
                        onUpdateCheck: () => _updateCheck(
                          comicId: comic.comicId,
                          title: comic.title,
                        ),
                        onChapters: () => _showChapters(comic),
                        onDelete: () => _deleteComic(comic),
                      );
                    },
                  ),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(AppDimens.paddingL),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(AppDimens.paddingL),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('漫画列表加载失败: $e'),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () =>
                            ref.invalidate(comixComicsProvider),
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('重试'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _stopTask(String taskId) async {
    try {
      await ref.read(comixBoardProvider.notifier).stopTask(taskId);
      _snack('已发送中断指令：$taskId');
    } catch (e) {
      _snack('中断失败: $e');
    }
  }

  T? _firstWhereOrNull<T>(List<T> list, bool Function(T) test) {
    for (final item in list) {
      if (test(item)) return item;
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// 候选行
// ---------------------------------------------------------------------------

class _CandidateTile extends StatelessWidget {
  final ComixCandidate candidate;
  final int index;
  final VoidCallback onAdd;

  const _CandidateTile({
    required this.candidate,
    required this.index,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading: _StatusChip(
          ok: candidate.match == 'exact',
          label: candidate.match == 'exact' ? '精确' : '模糊',
        ),
        title: Text(
          candidate.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '[${candidate.siteName}] ${candidate.detailUrl}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: OutlinedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add_rounded, size: 16),
          label: Text('添加 #$index'),
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 漫画行
// ---------------------------------------------------------------------------

class _ComicTile extends StatelessWidget {
  final ComixComic comic;
  final VoidCallback onDownload;
  final VoidCallback onUpdateCheck;
  final VoidCallback onChapters;
  final VoidCallback onDelete;

  const _ComicTile({
    required this.comic,
    required this.onDownload,
    required this.onUpdateCheck,
    required this.onChapters,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final pending = comic.totalChapters - comic.downloaded;
    return ListTile(
      dense: true,
      title: Text(
        comic.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '[${comic.siteName}] 已下载 ${comic.downloaded}/${comic.totalChapters} 章'
        '${comic.failed > 0 ? ' · 失败 ${comic.failed}' : ''}'
        '${pending > 0 ? ' · 待下载 $pending' : ''}'
        '${comic.isLegacy ? ' · legacy(不参与追更)' : ''}',
      ),
      trailing: Wrap(
        spacing: 4,
        children: [
          IconButton(
            tooltip: '下载',
            onPressed: onDownload,
            icon: const Icon(Icons.download_rounded, size: 18),
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            tooltip: '追更检查',
            onPressed: comic.isLegacy ? null : onUpdateCheck,
            icon: const Icon(Icons.update_rounded, size: 18),
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            tooltip: '章节',
            onPressed: onChapters,
            icon: const Icon(Icons.list_alt_rounded, size: 18),
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            tooltip: '删除',
            onPressed: onDelete,
            icon: Icon(
              Icons.delete_outline_rounded,
              size: 18,
              color: Theme.of(context).colorScheme.error,
            ),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 任务面板
// ---------------------------------------------------------------------------

class _TaskPanel extends ConsumerWidget {
  final void Function(String taskId) onStop;

  const _TaskPanel({required this.onStop});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(comixBoardProvider);
    final tasks = board.tasks;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('任务面板', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(width: 8),
                if (board.refreshing)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                const Spacer(),
                Text(
                  '${tasks.where((t) => t.isRunning).length} 运行中 / ${tasks.length} 总',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            if (board.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '任务刷新失败: ${board.error}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: AppDimens.spacingS),
            if (tasks.isEmpty)
              const Padding(
                padding: EdgeInsets.all(AppDimens.paddingL),
                child: Center(child: Text('暂无任务')),
              )
            else
              for (final task in tasks) ...[
                _TaskTile(task: task, onStop: () => onStop(task.id)),
                const SizedBox(height: AppDimens.spacingS),
              ],
          ],
        ),
      ),
    );
  }
}

class _TaskTile extends StatefulWidget {
  final ComixTask task;
  final VoidCallback onStop;

  const _TaskTile({required this.task, required this.onStop});

  @override
  State<_TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends State<_TaskTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.paddingM,
          vertical: AppDimens.paddingS,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _statusChip(task.status),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${task.name} (${task.id})',
                    style: Theme.of(context).textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (task.isRunning)
                  IconButton(
                    tooltip: '中断',
                    onPressed: widget.onStop,
                    icon: Icon(
                      Icons.stop_circle_outlined,
                      color: Theme.of(context).colorScheme.error,
                      size: 20,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                IconButton(
                  tooltip: _expanded ? '收起' : '展开日志',
                  onPressed: () => setState(() => _expanded = !_expanded),
                  icon: Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            Text(
              task.command,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (task.error != null && task.error!.isNotEmpty)
              Text(
                task.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (task.result != null)
              Text(
                _taskSummary(task),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (task.pid > 0)
              Text(
                'PID ${task.pid} · 开始 ${task.startedAt ?? '-'}'
                '${task.finishedAt != null ? ' · 结束 ${task.finishedAt}' : ''}'
                '${task.exitCode != null ? ' · exit ${task.exitCode}' : ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (_expanded && task.logs.isNotEmpty) ...[
              const Divider(height: 12),
              Container(
                constraints: const BoxConstraints(maxHeight: 220),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(AppDimens.smallBorderRadius),
                ),
                padding: const EdgeInsets.all(AppDimens.paddingS),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final log in task.logs)
                        SelectableText(
                          '[${log.stream}] ${log.text}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 章节对话框
// ---------------------------------------------------------------------------

class _ChaptersDialog extends StatelessWidget {
  final ComixComic comic;
  final List<ComixChapter> chapters;

  const _ChaptersDialog({required this.comic, required this.chapters});

  @override
  Widget build(BuildContext context) {
    final done = chapters.where((c) => c.status == 'done').length;
    final failed = chapters.where((c) => c.status == 'failed').length;
    return AlertDialog(
      title: Text('章节：${comic.title}'),
      content: SizedBox(
        width: 520,
        height: 480,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '共 ${chapters.length} 章 · 已下载 $done · 失败 $failed',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: chapters.length,
                itemBuilder: (context, index) {
                  final ch = chapters[index];
                  return ListTile(
                    dense: true,
                    leading: _ChapterStatusChip(status: ch.status),
                    title: Text(
                      '${ch.chapterNo} · ${ch.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      ch.status == 'done'
                          ? '${ch.pageCount} 页 · ${ch.relDir}'
                          : (ch.error.isNotEmpty ? ch.error : ch.relDir),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 通用小组件
// ---------------------------------------------------------------------------

class _StatusChip extends StatelessWidget {
  final bool ok;
  final String label;

  const _StatusChip({required this.ok, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = ok ? Colors.greenAccent.shade400 : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: color),
      ),
    );
  }
}

class _ChapterStatusChip extends StatelessWidget {
  final String status;

  const _ChapterStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      'done' => (Colors.greenAccent.shade400, '完成'),
      'failed' => (Colors.redAccent, '失败'),
      _ => (Colors.blueGrey, '待下'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}

Widget _statusChip(ComixTaskStatus status) {
  final (color, label) = switch (status) {
    ComixTaskStatus.running => (Colors.blueAccent, '运行中'),
    ComixTaskStatus.finished => (Colors.greenAccent.shade400, '完成'),
    ComixTaskStatus.failed => (Colors.redAccent, '失败'),
    ComixTaskStatus.killed => (Colors.orange, '已中断'),
    ComixTaskStatus.unknown => (Colors.grey, '未知'),
  };
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withValues(alpha: 0.7)),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 11, color: color),
    ),
  );
}

String _taskSummary(ComixTask task) {
  final result = task.result;
  if (result == null) return '';
  final ok = result['ok'] == true;
  final data = result['data'];
  if (ok && data is Map<String, dynamic>) {
    final parts = <String>[];
    if (data['title'] is String) {
      parts.add(data['title'].toString());
    }
    if (data['reports'] is List) {
      final reports = data['reports'] as List;
      var newCount = 0;
      for (final report in reports) {
        if (report is Map<String, dynamic>) {
          final news = report['new_chapters'];
          if (news is List) newCount += news.length;
        }
      }
      parts.add('检查 ${reports.length} 部');
      parts.add(newCount > 0 ? '新增 $newCount 章' : '无新章节');
    }
    if (data['downloaded'] is List) {
      parts.add('下载 ${(data['downloaded'] as List).length} 章');
    }
    if (data['failed'] is List && (data['failed'] as List).isNotEmpty) {
      parts.add('失败 ${(data['failed'] as List).length} 章');
    }
    if (data['message'] is String && (data['message'] as String).isNotEmpty) {
      parts.add(data['message'].toString());
    }
    if (data['recovered_tasks'] != null || data['removed_temp_dirs'] != null) {
      parts.add(
        '回收任务 ${data['recovered_tasks'] ?? 0} · 清理临时目录 ${data['removed_temp_dirs'] ?? 0}',
      );
    }
    if (parts.isNotEmpty) return parts.join(' · ');
    return '完成';
  }
  if (!ok) {
    final error = result['error'] as String? ?? '';
    final candidates = result['candidates'];
    if (candidates is List && candidates.isNotEmpty) {
      return '需要选择候选（${candidates.length} 个）: $error';
    }
    return '业务错误: $error';
  }
  return '';
}
