import 'package:flutter/material.dart';

import 'package:northstar/app/theme.dart';
import 'package:northstar/domain/comix/models/comix_models.dart';
import 'package:northstar/ui/comix/widgets/comix_widgets.dart';

/// 章节区间格式校验：`1-5,8,10-12`（正整数/正区间，逗号分隔）。
/// 返回错误提示；null 表示合法（空串视为未填写）。
String? validateChapterRange(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  for (final part in text.split(',')) {
    final seg = part.trim();
    if (seg.isEmpty) continue;
    final match = RegExp(r'^(\d+)(?:-(\d+))?$').firstMatch(seg);
    if (match == null) {
      return '章节区间格式无效："$seg"（应形如 1-5,8,10-12）';
    }
    final start = int.parse(match.group(1)!);
    final endText = match.group(2);
    if (start <= 0) return '章节号必须为正整数："$seg"';
    if (endText != null) {
      final end = int.parse(endText);
      if (end <= 0) return '章节号必须为正整数："$seg"';
      if (end < start) return '区间结束值小于起始值："$seg"';
    }
  }
  return null;
}

/// "仅下载最新 N 章"校验。返回错误提示；null 表示合法（空串=不限量）。
String? validateLatestCount(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  final parsed = int.tryParse(text);
  if (parsed == null) return '请输入正整数（留空表示不限量）';
  if (parsed <= 0) return 'N 必须大于 0（留空表示不限量）';
  return null;
}

/// 下载选项。
class DownloadOptions {
  final int? latest;
  final String? range;
  final bool noRetryFailed;

  const DownloadOptions({this.latest, this.range, this.noRetryFailed = false});

  Map<String, dynamic> toBody(int comicId) {
    return <String, dynamic>{
      'comic_id': comicId,
      if (latest != null) 'latest': latest,
      if (range != null && range!.isNotEmpty) 'range': range,
      if (noRetryFailed) 'no_retry_failed': true,
    };
  }
}

/// 更新检查选项。
class UpdateCheckOptions {
  final bool download;
  final int? latest;

  const UpdateCheckOptions({this.download = false, this.latest});

  Map<String, dynamic> toBody({int? comicId, bool all = false}) {
    return <String, dynamic>{
      if (comicId != null) 'comic_id': comicId,
      if (all) 'all': true,
      if (download) 'download': true,
      if (download && latest != null) 'latest': latest,
    };
  }
}

/// 删除选项。
class DeleteOptions {
  final bool keepFiles;

  const DeleteOptions({this.keepFiles = false});

  Map<String, dynamic> toBody(int comicId) {
    return <String, dynamic>{
      'comic_id': comicId,
      if (keepFiles) 'keep_files': true,
    };
  }
}

/// 展示下载选项对话框。
Future<DownloadOptions?> showDownloadDialog(
  BuildContext context,
  ComixComic comic,
) {
  return showDialog<DownloadOptions>(
    context: context,
    builder: (_) => _DownloadDialog(comic: comic),
  );
}

/// 展示更新检查选项对话框。
Future<UpdateCheckOptions?> showUpdateCheckDialog(
  BuildContext context, {
  String? comicTitle,
  bool all = false,
}) {
  return showDialog<UpdateCheckOptions>(
    context: context,
    builder: (_) => _UpdateCheckDialog(comicTitle: comicTitle, all: all),
  );
}

/// 展示删除确认对话框。
Future<DeleteOptions?> showDeleteComicDialog(
  BuildContext context,
  ComixComic comic,
) {
  return showDialog<DeleteOptions>(
    context: context,
    builder: (_) => _DeleteDialog(comic: comic),
  );
}

// ---------------------------------------------------------------------------
// 下载对话框
// ---------------------------------------------------------------------------

class _DownloadDialog extends StatefulWidget {
  final ComixComic comic;

  const _DownloadDialog({required this.comic});

  @override
  State<_DownloadDialog> createState() => _DownloadDialogState();
}

class _DownloadDialogState extends State<_DownloadDialog> {
  bool _noRetryFailed = false;
  String? _error;
  final _latestController = TextEditingController();
  final _rangeController = TextEditingController();

  @override
  void dispose() {
    _latestController.dispose();
    _rangeController.dispose();
    super.dispose();
  }

  void _submit() {
    // 非法输入此前会被静默丢弃（latest 变 null = 全量下载；range 抛错导致
    // 任务以空错误信息失败），必须在这里拦下并说清原因。
    final latestError = validateLatestCount(_latestController.text);
    final rangeError = validateChapterRange(_rangeController.text);
    final latestText = _latestController.text.trim();
    final rangeText = _rangeController.text.trim();
    if (latestError != null || rangeError != null) {
      setState(() => _error = latestError ?? rangeError);
      return;
    }
    if (latestText.isNotEmpty && rangeText.isNotEmpty) {
      setState(() => _error = '「最新 N 章」与「章节区间」不能同时填写');
      return;
    }
    Navigator.of(context).pop(
      DownloadOptions(
        latest: latestText.isEmpty ? null : int.parse(latestText),
        range: rangeText,
        noRetryFailed: _noRetryFailed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pending = widget.comic.pending;
    return AlertDialog(
      title: const Text('增量下载'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.comic.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '已下载 ${widget.comic.downloaded}/${widget.comic.totalChapters} 章，'
              '未下载 $pending 章'
              '${widget.comic.failed > 0 ? '，失败 ${widget.comic.failed} 章（会重试）' : ''}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Divider(height: 20),
            TextField(
              controller: _latestController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '仅下载最新 N 章（留空=全部待下载章节）',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _rangeController,
              decoration: const InputDecoration(
                labelText: '章节区间（如 1-5,8，与最新N章二选一）',
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _noRetryFailed,
              onChanged: (v) => setState(() => _noRetryFailed = v ?? false),
              title: const Text('不重试失败章节'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('开始下载'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 更新检查对话框
// ---------------------------------------------------------------------------

class _UpdateCheckDialog extends StatefulWidget {
  final String? comicTitle;
  final bool all;

  const _UpdateCheckDialog({this.comicTitle, this.all = false});

  @override
  State<_UpdateCheckDialog> createState() => _UpdateCheckDialogState();
}

class _UpdateCheckDialogState extends State<_UpdateCheckDialog> {
  bool _download = false;
  String? _error;
  final _latestController = TextEditingController();

  @override
  void dispose() {
    _latestController.dispose();
    super.dispose();
  }

  void _submit() {
    final latestError = _download ? validateLatestCount(_latestController.text) : null;
    if (latestError != null) {
      setState(() => _error = latestError);
      return;
    }
    final latestText = _latestController.text.trim();
    Navigator.of(context).pop(
      UpdateCheckOptions(
        download: _download,
        latest: _download && latestText.isNotEmpty ? int.parse(latestText) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.all ? '全站追更检查' : '连载更新检查'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.all
                  ? '遍历全部已登记漫画，对比站点最新章节'
                  : '检查「${widget.comicTitle ?? ''}」是否有新章节',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const Divider(height: 20),
            CheckboxListTile(
              value: _download,
              onChanged: (v) => setState(() {
                _download = v ?? false;
                _error = null;
              }),
              title: const Text('自动下载（新章节 + 尚未下载的章节）'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
            ),
            if (_download) ...[
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 6),
                child: Text(
                  '已勾选：会同时补齐「已登记但从未下载」的章节'
                  '${widget.all ? '，对全部漫画生效（可能耗时较长且占用磁盘）' : ''}。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              TextField(
                controller: _latestController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '自动下载时仅取最新 N 章（留空=全部）',
                ),
              ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('开始检查'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 删除对话框
// ---------------------------------------------------------------------------

class _DeleteDialog extends StatefulWidget {
  final ComixComic comic;

  const _DeleteDialog({required this.comic});

  @override
  State<_DeleteDialog> createState() => _DeleteDialogState();
}

class _DeleteDialogState extends State<_DeleteDialog> {
  bool _keepFiles = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('删除漫画'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '确认删除「${widget.comic.title}」吗？',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '默认同时删除数据库记录与本地文件（${widget.comic.relDir}），不可恢复。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Divider(height: 20),
            CheckboxListTile(
              value: _keepFiles,
              onChanged: (v) => setState(() => _keepFiles = v ?? false),
              title: const Text('仅删记录，保留本地文件'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
          ),
          onPressed: () {
            Navigator.of(context).pop(DeleteOptions(keepFiles: _keepFiles));
          },
          child: const Text('确认删除'),
        ),
      ],
    );
  }
}

/// 展示章节列表对话框（带搜索过滤，便于大章节数漫画）。
Future<void> showChaptersDialog(
  BuildContext context, {
  required ComixComic comic,
  required List<ComixChapter> chapters,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _ChaptersDialog(comic: comic, chapters: chapters),
  );
}

class _ChaptersDialog extends StatefulWidget {
  final ComixComic comic;
  final List<ComixChapter> chapters;

  const _ChaptersDialog({required this.comic, required this.chapters});

  @override
  State<_ChaptersDialog> createState() => _ChaptersDialogState();
}

class _ChaptersDialogState extends State<_ChaptersDialog> {
  final _filterController = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final done = widget.chapters.where((c) => c.status == 'done').length;
    final failed = widget.chapters.where((c) => c.status == 'failed').length;

    final filtered = _filter.isEmpty
        ? widget.chapters
        : widget.chapters.where((c) {
            final keyword = _filter.toLowerCase();
            return c.title.toLowerCase().contains(keyword) ||
                '${c.chapterNo}'.contains(keyword) ||
                c.status.contains(keyword);
          }).toList();

    return AlertDialog(
      title: Text('章节：${widget.comic.title}'),
      content: SizedBox(
        width: 540,
        height: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '共 ${widget.chapters.length} 章 · 已下载 $done · 失败 $failed',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _filterController,
              decoration: const InputDecoration(
                labelText: '过滤（标题/章节号/状态）',
                prefixIcon: Icon(Icons.search_rounded, size: 18),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _filter = v.trim()),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final ch = filtered[index];
                  return ListTile(
                    dense: true,
                    leading: ChapterStatusChip(status: ch.status),
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
