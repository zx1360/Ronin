import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:torrid/features/chat/models/chat_models.dart';

/// "问问AI"入口：跳到对话页并预置该媒体，用户直接键入问题。
///
/// 只带媒体 ID：图片由后端就地取用，手机端不需要先下载再上传。
void askAiAboutMedia(
  BuildContext context, {
  required String mediaId,
  String? fileName,
}) {
  context.pushNamed(
    'chat',
    extra: ChatLaunchArgs(
      attachments: [ChatAttachment.media(mediaId, fileName: fileName)],
    ),
  );
}
