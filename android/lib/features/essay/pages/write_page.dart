import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:torrid/core/modals/confirm_modal.dart';
import 'package:torrid/core/services/io/io_service.dart';
import 'package:torrid/core/models/mood.dart';
import 'package:torrid/core/utils/util.dart';
import 'package:torrid/core/widgets/mood_selector/mood_selector.dart';
import 'package:torrid/features/essay/models/essay.dart';
import 'package:torrid/features/essay/models/essay_draft.dart';
import 'package:torrid/features/essay/providers/box_provider.dart';
import 'package:torrid/features/essay/providers/essay_notifier_provider.dart';
import 'package:torrid/features/essay/providers/status_provider.dart';
import 'package:torrid/features/essay/services/essay_draft_store.dart';
import 'package:torrid/features/essay/widgets/label_selector.dart';
import 'package:torrid/features/essay/widgets/label_editor.dart';
import 'package:torrid/features/essay/widgets/write/image_preview.dart';

class EssayWritePage extends ConsumerStatefulWidget {
  final EssayDraft? draft;
  final Essay? original;
  const EssayWritePage({super.key, this.draft, this.original});

  @override
  ConsumerState<EssayWritePage> createState() => _EssayWritePageState();
}

class _EssayWritePageState extends ConsumerState<EssayWritePage>
    with WidgetsBindingObserver {
  final _title = TextEditingController();
  final _content = TextEditingController();
  late final EssayDraftStore _store;
  late EssayDraft _draft;
  final _labels = <String>[];
  final _images = <String>[];
  MoodType? _mood;
  bool _busy = false;
  bool _allowPop = false;
  String _status = '草稿仅存本机';
  int _revision = 0;
  Timer? _autosave;

  @override
  void initState() {
    super.initState();
    _store = ref.read(essayDraftStoreProvider);
    final original = widget.original;
    _draft =
        widget.draft ??
        (original == null ? null : _store.forEssay(original.id)) ??
        EssayDraft(
          essay:
              original ??
              Essay(
                id: generateId(),
                date: DateTime.now(),
                wordCount: 0,
                content: '',
                imgs: [],
                labels: [],
                messages: [],
              ),
          original: original,
          updatedAt: DateTime.now(),
        );
    _title.text = _draft.essay.title;
    _content.text = _draft.essay.content;
    _labels.addAll(_draft.essay.labels);
    _images.addAll(_draft.essay.imgs);
    _mood = _draft.essay.mood;
    _title.addListener(_changed);
    _content.addListener(_changed);
    WidgetsBinding.instance.addObserver(this);
    if (_images.any((image) => !image.startsWith('essay_drafts/'))) {
      _busy = true;
      unawaited(_cacheOriginalImages());
    }
  }

  Future<void> _cacheOriginalImages() async {
    try {
      for (var i = 0; i < _images.length; i++) {
        if (_images[i].startsWith('essay_drafts/')) continue;
        _images[i] = await _store.importImage(
          _draft.essay.id,
          await IoService.userFile(_images[i]),
        );
      }
      await _persist();
    } catch (e) {
      _error(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  EssayDraft _snapshot() => EssayDraft(
    essay: _draft.essay.copyWith(
      title: _title.text,
      content: _content.text,
      wordCount: _content.text.trim().length,
      labels: List.of(_labels),
      imgs: List.of(_images),
      mood: _mood,
      clearMood: _mood == null,
    ),
    original: _draft.original,
    updatedAt: DateTime.now(),
  );

  void _changed() {
    _autosave?.cancel();
    setState(() => _status = '正在编辑…');
    _autosave = Timer(
      const Duration(milliseconds: 400),
      () => unawaited(_persist()),
    );
  }

  Future<bool> _persist() async {
    _autosave?.cancel();
    final revision = ++_revision;
    _draft = _snapshot();
    if (!_draft.hasContent && !_store.box.containsKey(_draft.essay.id)) {
      return true;
    }
    try {
      await _store.save(_draft);
      if (mounted && revision == _revision) setState(() => _status = '草稿已存本机');
      return true;
    } catch (e) {
      if (mounted) setState(() => _status = '草稿保存失败，请重试：$e');
      return false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && !_allowPop && !_busy) {
      unawaited(_cacheBeforePause());
    }
  }

  Future<void> _cacheBeforePause() async {
    if (await _persist()) {
      try {
        await _store.flush();
      } catch (e) {
        if (mounted) setState(() => _status = '草稿保存失败，请重试：$e');
      }
    }
  }

  Future<void> _close() async {
    if (!mounted) return;
    setState(() => _allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.pop(context);
  }

  Future<void> _leave() async {
    if (_busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _busy = true);
    try {
      if (await _persist()) {
        await _store.flush();
        await _close();
      }
    } catch (e) {
      _error(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _error(Object error) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _discard() async {
    if (_busy) return;
    await showConfirmDialog(
      context: context,
      title: '丢弃草稿',
      content: _draft.original == null
          ? '确认丢弃这份草稿及其图片？'
          : '确认丢弃这次编辑？已保存的原随笔会保留。',
      confirmFunc: () async {
        if (!mounted) return;
        _autosave?.cancel();
        FocusManager.instance.primaryFocus?.unfocus();
        setState(() => _busy = true);
        try {
          await _store.remove(_draft.essay.id);
          await _store.flush();
          await _close();
          // 图片清理失败不影响已完成的丢弃。
          try {
            await _store.cleanImages(_draft.essay.id);
          } catch (_) {}
        } catch (e) {
          _error(e);
        } finally {
          if (mounted) setState(() => _busy = false);
        }
      },
    );
  }

  Future<void> _pickImage() async {
    setState(() => _busy = true);
    try {
      final files = await ImagePicker().pickMultiImage();
      for (final file in files.take(9 - _images.length)) {
        final image = await _store.importImage(
          _draft.essay.id,
          File(file.path),
        );
        if (!mounted) return;
        setState(() => _images.add(image));
        await _persist();
      }
    } catch (e) {
      _error(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _editableFields(Essay essay) => jsonEncode(
    essay.toJson()
      ..remove('messages')
      ..remove('updated_at'),
  );

  Future<void> _saveEssay() async {
    if (_busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (_content.text.trim().isEmpty || _labels.isEmpty || _labels.length > 4) {
      _error('正文不能为空，请选择 1–4 个标签');
      return;
    }
    setState(() => _busy = true);
    try {
      if (!await _persist()) return;
      await _store.flush();
      final base = _draft.original;
      final current = ref.read(essayBoxProvider).get(_draft.essay.id);
      if (base != null &&
          (current == null ||
              _editableFields(current) != _editableFields(base))) {
        throw const FormatException('原随笔已被修改或同步替换。草稿已保留，请核对原文后再处理');
      }
      var essay = _draft.essay.copyWith(
        title: _title.text.trim(),
        content: _content.text.trim(),
        date: base?.date ?? DateTime.now(),
        messages: current?.messages ?? [],
      );
      essay = await _store.publish(
        essay,
        (published) => ref
            .read(essayServiceProvider.notifier)
            .writeEssay(essay: published),
      );
      // 保存成功后再删草稿；清理失败时保留可继续的同 ID 草稿。
      _draft = EssayDraft(
        essay: essay,
        original: essay,
        updatedAt: DateTime.now(),
      );
      await _store.save(_draft);
      await _store.remove(essay.id);
      await _store.flush();
      await _close();
      try {
        await _store.cleanImages(essay.id);
      } catch (_) {}
    } catch (e) {
      _error(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final labels = ref.watch(labelsProvider);
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_leave());
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_draft.original == null ? '写随笔' : '编辑随笔'),
          actions: [
            IconButton(
              tooltip: '丢弃草稿',
              onPressed: _busy ? null : _discard,
              icon: const Icon(Icons.delete_outline),
            ),
            TextButton(
              onPressed: _busy ? null : _saveEssay,
              child: const Text('保存随笔'),
            ),
          ],
        ),
        body: AbsorbPointer(
          absorbing: _busy,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                _busy ? '正在处理…' : _status,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              TextField(
                controller: _title,
                readOnly: _busy,
                maxLength: 100,
                decoration: const InputDecoration(
                  hintText: '标题（可选）',
                  border: InputBorder.none,
                ),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              TextField(
                controller: _content,
                readOnly: _busy,
                minLines: 8,
                maxLines: null,
                onTapOutside: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
                decoration: const InputDecoration(
                  hintText: '记下此刻…',
                  border: InputBorder.none,
                ),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              const Text('心情'),
              MoodSelector(
                selectedMood: _mood,
                compact: false,
                iconSize: 28,
                onMoodChanged: (mood) {
                  setState(() => _mood = mood);
                  _changed();
                },
              ),
              const SizedBox(height: 16),
              if (_images.isNotEmpty)
                ImagePreview(
                  images: _images,
                  onRemove: (index) {
                    setState(() => _images.removeAt(index));
                    _changed();
                  },
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _images.length >= 9 ? null : _pickImage,
                  icon: const Icon(Icons.add_photo_alternate),
                  label: const Text('添加图片（最多 9 张）'),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(child: Text('标签（1–4 个）')),
                  TextButton(
                    onPressed: () => showLabelEditor(context, ref),
                    child: const Text('新增标签'),
                  ),
                ],
              ),
              LabelSelector(
                labels: labels,
                selectedLabels: _labels,
                onToggleLabel: (id) {
                  if (!_labels.contains(id) && _labels.length >= 4) {
                    _error('最多选择 4 个标签');
                    return;
                  }
                  setState(
                    () => _labels.contains(id)
                        ? _labels.remove(id)
                        : _labels.add(id),
                  );
                  _changed();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _autosave?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _title.dispose();
    _content.dispose();
    super.dispose();
  }
}
