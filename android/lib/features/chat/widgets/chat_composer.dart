import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:torrid/app/theme/theme_book.dart';
import 'package:torrid/core/services/io/io_service.dart';
import 'package:torrid/core/utils/util.dart';
import 'package:torrid/features/chat/models/chat_models.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';

/// 输入栏：图片附件预览 + 多行输入 + 发送/停止。
class ChatComposer extends ConsumerStatefulWidget {
  const ChatComposer({
    super.key,
    required this.streaming,
    required this.onSend,
    required this.onStop,
    this.initialAttachments = const [],
    this.autoFocus = false,
  });

  final bool streaming;
  final void Function(String text, List<ChatAttachment> attachments) onSend;
  final VoidCallback onStop;

  /// 进入页面时预置的附件（"问问AI"带过来的图片）。
  final List<ChatAttachment> initialAttachments;
  final bool autoFocus;

  @override
  ConsumerState<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends ConsumerState<ChatComposer> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final List<ChatAttachment> _attachments = [];
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    _attachments.addAll(widget.initialAttachments);
    if (widget.autoFocus) {
      // 进入即处于键入态：等首帧布局完成再请求焦点，否则软键盘不会弹出
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        // 手机原图动辄数 MB：压到长边 1280 再上传，视觉问答足够清晰
        maxWidth: 1280,
        imageQuality: 85,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      final extension = picked.path.split('.').last.toLowerCase();
      final relativePath =
          'img_storage/chat/${generateId()}.${extension.length <= 4 ? extension : 'jpg'}';
      await IoService.saveImageToExternalStorage(
        relativePath: relativePath,
        bytes: bytes,
      );
      if (!mounted) return;
      setState(() {
        _attachments.add(
          ChatAttachment.local(relativePath, fileName: picked.name),
        );
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('选择图片失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _submit() {
    if (widget.streaming) return;
    final text = _controller.text;
    if (text.trim().isEmpty && _attachments.isEmpty) return;
    widget.onSend(text, List.of(_attachments));
    _controller.clear();
    setState(() => _attachments.clear());
  }

  @override
  Widget build(BuildContext context) {
    final canSend = _controller.text.trim().isNotEmpty || _attachments.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        border: Border(top: BorderSide(color: AppTheme.outline.withAlpha(120))),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_attachments.isNotEmpty) _buildAttachmentPreview(),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: _picking || widget.streaming ? null : _pickImage,
                    icon: const Icon(Icons.image_outlined),
                    color: AppTheme.primary,
                    tooltip: '上传图片',
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.newline,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: '说点什么…',
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _buildActionButton(canSend),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(bool canSend) {
    if (widget.streaming) {
      return IconButton.filled(
        onPressed: widget.onStop,
        icon: const Icon(Icons.stop_rounded),
        tooltip: '停止生成',
      );
    }
    return IconButton.filled(
      onPressed: canSend ? _submit : null,
      icon: const Icon(Icons.arrow_upward_rounded),
      tooltip: '发送',
    );
  }

  Widget _buildAttachmentPreview() {
    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        itemCount: _attachments.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = _attachments[index];
          return Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: _buildThumb(item),
                ),
              ),
              Positioned(
                right: -6,
                top: -6,
                child: GestureDetector(
                  onTap: () => setState(() => _attachments.removeAt(index)),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: AppTheme.onSurface,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close,
                        size: 13, color: AppTheme.surface),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildThumb(ChatAttachment item) {
    if (item.isLocal) {
      return FutureBuilder<File?>(
        future: IoService.getImageFile(item.imagePath!),
        builder: (context, snapshot) {
          final file = snapshot.data;
          if (file == null) {
            return const ColoredBox(color: AppTheme.surfaceContainerHighest);
          }
          return Image.file(file, fit: BoxFit.cover);
        },
      );
    }
    final api = ref.read(apiClientManagerProvider);
    return CachedNetworkImage(
      imageUrl: '${api.baseUrl}/API/gallery/${item.mediaId}/thumb',
      httpHeaders: api.headers,
      fit: BoxFit.cover,
      errorWidget: (_, __, ___) => const ColoredBox(
        color: AppTheme.surfaceContainerHighest,
        child: Icon(Icons.image, color: AppTheme.onSurfaceVariant),
      ),
    );
  }
}
