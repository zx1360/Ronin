import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'package:torrid/app/theme/theme_book.dart';
import 'package:torrid/core/constants/spacing.dart';
import 'package:torrid/core/services/io/io_service.dart';
import 'package:torrid/providers/personalization/personalization_providers.dart';

/// 用户信息编辑页面
class ProfileUser extends ConsumerStatefulWidget {
  const ProfileUser({super.key});

  @override
  ConsumerState<ProfileUser> createState() => _ProfileUserState();
}

class _ProfileUserState extends ConsumerState<ProfileUser> {
  final ImagePicker _picker = ImagePicker();
  final Uuid _uuid = const Uuid();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('个人资料'),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                // 头像区域
                _buildAvatarSection(settings.avatarPath),
                const SizedBox(height: AppSpacing.lg),

                // 昵称
                _buildEditableField(
                  label: '昵称',
                  value: settings.nickname,
                  icon: Icons.person_outline,
                  onTap: () => _editNickname(settings.nickname),
                ),
                const SizedBox(height: AppSpacing.md),

                // 签名
                _buildEditableField(
                  label: '签名',
                  value: settings.signature,
                  icon: Icons.edit_note_outlined,
                  onTap: () => _editSignature(settings.signature),
                ),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  /// 头像区域
  Widget _buildAvatarSection(String? avatarPath) {
    return Column(
      children: [
        GestureDetector(
          onTap: _showAvatarOptions,
          child: Stack(
            children: [
              // 头像
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.primaryContainer,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withAlpha(40),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: _buildAvatarImage(avatarPath),
                ),
              ),
              // 编辑按钮
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '点击更换头像',
          style: TextStyle(
            color: AppTheme.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  /// 构建头像图片
  Widget _buildAvatarImage(String? avatarPath) {
    if (avatarPath != null && avatarPath.isNotEmpty) {
      return FutureBuilder<File?>(
        future: IoService.getImageFile(avatarPath),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            return Image.file(
              snapshot.data!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _defaultAvatar(),
            );
          }
          return _defaultAvatar();
        },
      );
    }
    return _defaultAvatar();
  }

  /// 默认头像
  Widget _defaultAvatar() {
    return Image.asset(
      'assets/icons/six.png',
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: AppTheme.primaryContainer,
        child: Icon(
          Icons.person,
          size: 60,
          color: AppTheme.primary,
        ),
      ),
    );
  }

  /// 可编辑字段
  Widget _buildEditableField({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: AppTheme.primary),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.onSurfaceVariant,
          ),
        ),
        subtitle: Text(
          value,
          style: const TextStyle(fontSize: 16),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  /// 显示头像选项
  Future<void> _showAvatarOptions() async {
    final settings = ref.read(appSettingsProvider);
    final hasCustomAvatar = settings.avatarPath != null;

    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('从相册选择'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            if (hasCustomAvatar)
              ListTile(
                leading: const Icon(Icons.restore, color: Colors.red),
                title: const Text('恢复默认头像', style: TextStyle(color: Colors.red)),
                onTap: () => Navigator.pop(context, 'reset'),
              ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('取消'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );

    if (result == 'gallery') {
      await _pickAvatar();
    } else if (result == 'reset') {
      await _resetAvatar();
    }
  }

  /// 选择头像
  Future<void> _pickAvatar() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (picked == null) return;

      setState(() => _isLoading = true);

      final bytes = await picked.readAsBytes();
      final ext = p.extension(picked.path).toLowerCase();
      final fileName = 'avatar_${_uuid.v4()}$ext';

      final success = await ref
          .read(appSettingsProvider.notifier)
          .updateAvatar(bytes, fileName);

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(success ? '头像更新成功' : '头像更新失败')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    }
  }

  /// 重置头像
  Future<void> _resetAvatar() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认恢复'),
        content: const Text('确定要恢复默认头像吗？'),
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

    if (confirmed == true) {
      await ref.read(appSettingsProvider.notifier).clearAvatar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已恢复默认头像')),
        );
      }
    }
  }

  /// 编辑昵称
  Future<void> _editNickname(String currentNickname) async {
    final controller = TextEditingController(text: currentNickname);

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('修改昵称'),
        content: TextField(
          controller: controller,
          maxLength: 20,
          decoration: const InputDecoration(
            hintText: '输入昵称',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    // 保存结果后再 dispose，延迟足够时间确保对话框完全关闭
    final savedResult = result;
    Future.delayed(const Duration(milliseconds: 500), () {
      controller.dispose();
    });

    if (savedResult != null) {
      await ref.read(appSettingsProvider.notifier).updateNickname(savedResult);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('昵称已更新')),
        );
      }
    }
  }

  /// 编辑签名
  Future<void> _editSignature(String currentSignature) async {
    final controller = TextEditingController(text: currentSignature);

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('修改签名'),
        content: TextField(
          controller: controller,
          maxLength: 50,
          maxLines: 2,
          decoration: const InputDecoration(
            hintText: '输入个性签名',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    // 保存结果后再 dispose，延迟足够时间确保对话框完全关闭
    final savedResult = result;
    Future.delayed(const Duration(milliseconds: 500), () {
      controller.dispose();
    });

    if (savedResult != null) {
      await ref.read(appSettingsProvider.notifier).updateSignature(savedResult);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('签名已更新')),
        );
      }
    }
  }
}