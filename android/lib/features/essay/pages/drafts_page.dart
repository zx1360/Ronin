import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:torrid/features/essay/pages/write_page.dart';
import 'package:torrid/features/essay/services/essay_draft_store.dart';

class EssayDraftsPage extends ConsumerWidget {
  const EssayDraftsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('本机草稿')),
    body: ref
        .watch(essayDraftsProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('读取草稿失败：$error')),
          data: (drafts) => drafts.isEmpty
              ? const Center(child: Text('暂无草稿。写作中退出会自动保存到这里。'))
              : ListView(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('草稿仅保存在本机，不参与同步和 AI 回顾。'),
                    ),
                    for (final draft in drafts)
                      ListTile(
                        leading: Icon(
                          draft.original == null
                              ? Icons.note_add_outlined
                              : Icons.edit_note,
                        ),
                        title: Text(
                          draft.essay.title.trim().isNotEmpty
                              ? draft.essay.title
                              : draft.essay.content.trim().isNotEmpty
                              ? draft.essay.content.replaceAll('\n', ' ')
                              : '未命名草稿',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${draft.original == null ? "新随笔" : "编辑原文"} · ${DateFormat('MM-dd HH:mm').format(draft.updatedAt)}',
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EssayWritePage(draft: draft),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
  );
}
