import 'package:flutter/material.dart';

import 'package:northstar/app/theme.dart';
import 'package:northstar/domain/comix/models/comix_models.dart';

/// 添加漫画选项。
class AddComicOptions {
  final bool noDownload;
  final int? latest;
  final String? range;

  const AddComicOptions({
    required this.noDownload,
    this.latest,
    this.range,
  });

  /// 走 add-url：直接按候选的站点与详情 URL 添加，跳过重新搜索（确定性强）。
  Map<String, dynamic> toBody(ComixCandidate candidate) {
    return <String, dynamic>{
      'site': candidate.site,
      'url': candidate.detailUrl,
      if (noDownload) 'no_download': true,
      if (!noDownload && latest != null) 'latest': latest,
      if (!noDownload && range != null && range!.isNotEmpty) 'range': range,
    };
  }
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

/// 展示添加漫画选项对话框（候选确认后）。
Future<AddComicOptions?> showAddComicDialog(
  BuildContext context,
  ComixCandidate candidate,
) {
  return showDialog<AddComicOptions>(
    context: context,
    builder: (_) => _AddComicDialog(candidate: candidate),
  );
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
// 添加漫画对话框
// ---------------------------------------------------------------------------

class _AddComicDialog extends StatefulWidget {
  final ComixCandidate candidate;

  const _AddComicDialog({required this.candidate});

  @override
  State<_AddComicDialog> createState() => _AddComicDialogState();
}

class _AddComicDialogState extends State<_AddComicDialog> {
  bool _noDownload = false;
  final _latestController = TextEditingController();
  final _rangeController = TextEditingController();

  @override
  void dispose() {
    _latestController.dispose();
    _rangeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('添加漫画'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.candidate.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '[${widget.candidate.siteName}] ${widget.candidate.detailUrl}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Divider(height: 20),
            CheckboxListTile(
              value: _noDownload,
              onChanged: (v) => setState(() => _noDownload = v ?? false),
              title: const Text('仅登记不下载'),
              subtitle: const Text('只写入数据库，不下载图片（懒创建目录）'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
            ),
            const SizedBox(height: 8),
            if (!_noDownload) ...[
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
                  labelText: '章节区间（如 1-5,8,10-12，与最新N章二选一）',
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            final latest = int.tryParse(_latestController.text.trim());
            Navigator.of(context).pop(
              AddComicOptions(
                noDownload: _noDownload,
                latest: latest,
                range: _rangeController.text.trim(),
              ),
            );
          },
          child: const Text('确认添加'),
        ),
      ],
    );
  }
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
  final _latestController = TextEditingController();
  final _rangeController = TextEditingController();

  @override
  void dispose() {
    _latestController.dispose();
    _rangeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pending = widget.comic.totalChapters - widget.comic.downloaded;
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
              '已下载 ${widget.comic.downloaded}/${widget.comic.totalChapters} 章，待下载 $pending 章',
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
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            final latest = int.tryParse(_latestController.text.trim());
            Navigator.of(context).pop(
              DownloadOptions(
                latest: latest,
                range: _rangeController.text.trim(),
                noRetryFailed: _noRetryFailed,
              ),
            );
          },
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
  final _latestController = TextEditingController();

  @override
  void dispose() {
    _latestController.dispose();
    super.dispose();
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
              onChanged: (v) => setState(() => _download = v ?? false),
              title: const Text('发现新章节自动下载'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
            ),
            if (_download) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _latestController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '自动下载时仅取最新 N 章（留空=全部新章节）',
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            final latest = int.tryParse(_latestController.text.trim());
            Navigator.of(context).pop(
              UpdateCheckOptions(
                download: _download,
                latest: _download ? latest : null,
              ),
            );
          },
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
