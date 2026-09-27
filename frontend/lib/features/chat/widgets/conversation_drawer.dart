import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/app/theme/theme_book.dart';
import 'package:torrid/core/modals/confirm_modal.dart';
import 'package:torrid/features/chat/models/chat_models.dart';
import 'package:torrid/features/chat/providers/chat_providers.dart';

/// 会话列表抽屉：切换 / 删除 / 清空。
class ChatConversationDrawer extends ConsumerWidget {
  const ChatConversationDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chatControllerProvider);
    final controller = ref.read(chatControllerProvider.notifier);

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  const Text('对话记录',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  IconButton(
                    tooltip: '清空全部',
                    onPressed: state.conversations.isEmpty
                        ? null
                        : () => _confirmClear(context, ref),
                    icon: const Icon(Icons.delete_sweep_outlined, size: 20),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: state.conversations.isEmpty
                  ? const Center(
                      child: Text('暂无对话',
                          style: TextStyle(color: AppTheme.onSurfaceVariant)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: state.conversations.length,
                      itemBuilder: (context, index) {
                        final item = state.conversations[index];
                        return _ConversationTile(
                          conversation: item,
                          active: item.id == state.active?.id,
                          onTap: () {
                            controller.select(item.id);
                            Navigator.pop(context);
                          },
                          onDelete: () => _confirmDelete(context, ref, item),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    ChatConversation conversation,
  ) {
    return showConfirmDialog(
      context: context,
      title: '删除对话',
      content: '删除「${conversation.title}」及其全部消息？该操作不可撤销。',
      confirmFunc: () => ref
          .read(chatControllerProvider.notifier)
          .deleteConversation(conversation.id),
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) {
    return showConfirmDialog(
      context: context,
      title: '清空全部对话',
      content: '将删除本机上的全部对话记录与图片，该操作不可撤销。',
      confirmFunc: () async {
        await ref.read(chatControllerProvider.notifier).clearAll();
        if (context.mounted) Navigator.pop(context);
      },
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.active,
    required this.onTap,
    required this.onDelete,
  });

  final ChatConversation conversation;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final count = conversation.messages.length;
    return ListTile(
      dense: true,
      selected: active,
      selectedTileColor: AppTheme.primaryContainer.withAlpha(90),
      leading: const Icon(Icons.chat_bubble_outline, size: 18),
      title: Text(
        conversation.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14),
      ),
      subtitle: Text(
        '$count 条 · ${_formatTime(conversation.updatedAt)}',
        style: const TextStyle(fontSize: 11),
      ),
      trailing: IconButton(
        tooltip: '删除',
        onPressed: onDelete,
        icon: const Icon(Icons.delete_outline, size: 18),
      ),
      onTap: onTap,
    );
  }
}

String _formatTime(DateTime time) {
  final now = DateTime.now();
  String pad(int value) => value.toString().padLeft(2, '0');
  if (time.year == now.year &&
      time.month == now.month &&
      time.day == now.day) {
    return '${pad(time.hour)}:${pad(time.minute)}';
  }
  return '${time.month}/${time.day}';
}
