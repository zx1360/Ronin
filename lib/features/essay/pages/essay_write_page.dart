import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:torrid/features/essay/models/essay.dart';
import 'package:torrid/features/essay/models/label.dart';
import 'package:torrid/features/essay/providers/box_provider.dart';
import 'package:torrid/features/essay/providers/notifier_provider.dart';
import 'package:torrid/features/essay/providers/status_provider.dart';
import 'package:torrid/features/essay/widgets/write/image_preview.dart';
import 'package:torrid/features/essay/widgets/label_selector.dart';
import 'package:torrid/shared/utils/util.dart';

class EssayWritePage extends ConsumerStatefulWidget {
  const EssayWritePage({super.key});

  @override
  ConsumerState<EssayWritePage> createState() => _EssayWritePageState();
}

class _EssayWritePageState extends ConsumerState<EssayWritePage> {
  // 文本输入相关
  final TextEditingController _contentController = TextEditingController();
  final _contentFucusNode = FocusNode();
  final TextEditingController _newLabelController = TextEditingController();
  final _labelFucusNode = FocusNode();
  // 内容相关
  final List<String> _selectedLabels = [];
  final List<File> _selectedImages = [];

  @override
  void dispose() {
    _contentController.dispose();
    _newLabelController.dispose();
    super.dispose();
  }

  void _toggleLabel(String labelId) {
    setState(() {
      if (_selectedLabels.contains(labelId)) {
        _selectedLabels.remove(labelId);
      } else {
        _selectedLabels.add(labelId);
      }
    });
  }

  void _addNewLabel() {
    final labelName = _newLabelController.text.trim();
    if (labelName.isEmpty) return;
    _newLabelController.clear();

    ref.watch(essayServerProvider.notifier).addLabel(labelName);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage();

    if (pickedFiles.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(pickedFiles.map((file) => File(file.path)));
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _saveEssay() {
    // 验证内容
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('随笔内容不能为空')));
      return;
    }

    // 验证标签
    if (_selectedLabels.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请至少选择一个标签')));
      return;
    }

    // 创建随笔对象
    final essay = Essay(
      id: generateId(),
      date: DateTime.now(),
      wordCount: content.length,
      content: content,
      imgs: _selectedImages.map((file) => file.path).toList(),
      labels: _selectedLabels,
    );

    // 保存到 Hive
    final essaysBox = ref.read(essayBoxProvider);
    essaysBox.put(essay.id, essay);

    // 更新标签计数
    final labelsBox = ref.read(labelBoxProvider);
    for (final labelId in _selectedLabels) {
      final label = labelsBox.get(labelId);
      if (label != null) {
        labelsBox.put(
          labelId,
          Label(
            id: label.id,
            name: label.name,
            essayCount: label.essayCount + 1,
          ),
        );
      }
    }

    // 返回上一页
    Navigator.pop(context);

    // 显示成功提示
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('随笔保存成功')));
  }

  @override
  Widget build(BuildContext context) {
    final labels = ref.watch(labelsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('写随笔'),
        actions: [TextButton(onPressed: _saveEssay, child: const Text('保存'))],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 内容输入
            TextField(
              controller: _contentController,
              focusNode: _contentFucusNode,
              onTapOutside: (event) => _contentFucusNode.unfocus(),
              minLines: 6,
              maxLines: null,
              decoration: const InputDecoration(
                hintText: '请输入随笔内容...',
                border: InputBorder.none,
              ),
              style: Theme.of(context).textTheme.bodyLarge,
            ),

            const SizedBox(height: 16),

            // 图片选择
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ElevatedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.add_photo_alternate),
                  label: const Text('添加图片'),
                ),

                const SizedBox(height: 12),

                if (_selectedImages.isNotEmpty)
                  ImagePreview(images: _selectedImages, onRemove: _removeImage),
              ],
            ),

            const SizedBox(height: 24),

            // 标签选择
            const Text('选择标签:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),

            LabelSelector(
              labels: labels,
              selectedLabels: _selectedLabels,
              onToggleLabel: _toggleLabel,
            ),

            const SizedBox(height: 16),

            // 添加新标签
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newLabelController,
                    focusNode: _labelFucusNode,
                    onTapOutside: (event) => _labelFucusNode.unfocus(),
                    decoration: const InputDecoration(
                      hintText: '添加新标签...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addNewLabel,
                  child: const Text('添加'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
