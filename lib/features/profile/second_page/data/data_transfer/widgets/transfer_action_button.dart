/// 传输操作按钮组件
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/profile/second_page/data/data_transfer/models/transfer_progress.dart';
import 'package:torrid/features/profile/second_page/data/data_transfer/services/transfer_controller.dart';

/// 传输操作按钮
class TransferActionButton extends ConsumerWidget {
  final TransferAction action;
  final bool isAll;

  const TransferActionButton({
    super.key,
    required this.action,
    this.isAll = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(transferControllerProvider);
    final isDisabled = progress.isInProgress;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isDisabled ? 0.5 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: isDisabled ? Colors.grey[100] : Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          boxShadow: isDisabled
              ? null
              : [
                  const BoxShadow(
                    color: Colors.black12,
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
        ),
        child: TextButton.icon(
          onPressed: isDisabled ? null : () => _onPressed(context, ref),
          icon: Icon(
            _getIcon(),
            color: isDisabled
                ? Colors.grey
                : Theme.of(context).colorScheme.primary,
          ),
          label: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                action.label,
                style: TextStyle(
                  fontSize: 15,
                  color: isDisabled
                      ? Colors.grey
                      : (action.highlighted ? Colors.red : Colors.black87),
                ),
              ),
            ),
          ),
          style: TextButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            minimumSize: const Size(double.infinity, 50),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
        ),
      ),
    );
  }

  IconData _getIcon() {
    if (action.type == TransferType.sync) {
      return isAll
          ? Icons.download
          : action.target == TransferTarget.booklet
          ? Icons.check_circle
          : Icons.note;
    } else {
      return isAll ? Icons.upload : Icons.upload_file;
    }
  }

  Future<void> _onPressed(BuildContext context, WidgetRef ref) async {
    final confirmed = await _showConfirmDialog(context);
    if (!confirmed) return;

    final controller = ref.read(transferControllerProvider.notifier);

    if (isAll) {
      if (action.type == TransferType.sync) {
        await controller.syncAll();
      } else {
        await controller.backupAll();
      }
    } else {
      await controller.execute(type: action.type, target: action.target);
    }
  }

  Future<bool> _showConfirmDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认操作'),
        content: Text('确定${action.label}吗？'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    return result == true;
  }
}

/// 同步所有按钮
class SyncAllButton extends StatelessWidget {
  const SyncAllButton({super.key});

  @override
  Widget build(BuildContext context) {
    return TransferActionButton(
      action: const TransferAction(
        type: TransferType.sync,
        target: TransferTarget.booklet,
        label: '同步所有',
        highlighted: true,
      ),
      isAll: true,
    );
  }
}

/// 备份所有按钮
class BackupAllButton extends StatelessWidget {
  const BackupAllButton({super.key});

  @override
  Widget build(BuildContext context) {
    return TransferActionButton(
      action: const TransferAction(
        type: TransferType.backup,
        target: TransferTarget.booklet,
        label: '备份所有',
        highlighted: true,
      ),
      isAll: true,
    );
  }
}
