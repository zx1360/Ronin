import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:torrid/features/booklet/widgets/routine/global_variable.dart';
import 'package:torrid/features/booklet/widgets/routine/new_task.dart';

/// 构建任务输入项（新建样式时的单个任务表单）
/// [task]：task对象.
/// [onDelete]：删除任务回调
/// [onSelectImage]：选择图片回调
Widget inputItem({
  required NewTask task,
  required VoidCallback onDelete,
  required VoidCallback onSelectImage,
}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0xFFD4C8B8)),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 任务标题输入（必填）
        TextField(
          controller: task.titleCtrl,
          style: noteText,
          decoration: InputDecoration(
            labelText: '任务${task.index + 1}标题*',
            labelStyle: noteSmall,
            border: const OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFD4C8B8)),
              borderRadius: BorderRadius.all(Radius.circular(6)),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF8B5A2B)),
            ),
          ),
          maxLength: 20,
          maxLengthEnforcement: MaxLengthEnforcement.enforced,
        ),
        const SizedBox(height: 8),

        // 任务描述输入（可选）
        TextField(
          controller: task.descCtrl,
          style: noteText,
          decoration: InputDecoration(
            labelText: '任务${task.index + 1}描述（可选）',
            labelStyle: noteSmall,
            border: const OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFD4C8B8)),
              borderRadius: BorderRadius.all(Radius.circular(6)),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF8B5A2B)),
            ),
          ),
          maxLines: 2,
          maxLength: 50,
          maxLengthEnforcement: MaxLengthEnforcement.enforced,
        ),
        const SizedBox(height: 8),

        // 图片选择区域
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: onSelectImage,
              icon: const Icon(Icons.image, size: 16),
              label: Text('选择图片（可选）', style: noteSmall),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF8B5A2B),
                padding: EdgeInsets.zero,
              ),
            ),
            Spacer(),

            // 图片预览区域
            task.imagePath.isNotEmpty
                ? Expanded(
                    child: Container(
                      height: 140,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        image: DecorationImage(
                          image: FileImage(File(task.imagePath)),
                          fit: BoxFit.contain,
                        ),
                        border: Border.all(color: const Color(0xFFD4C8B8)),
                      ),
                    ),
                  )
                : Text('未选择图片', style: noteSmall),
          ],
        ),

        // 删除任务按钮
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: onDelete,
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            child: Text(
              '删除任务${task.index + 1}',
              style: noteSmall.copyWith(color: const Color(0xFFD32F2F)),
            ),
          ),
        ),
      ],
    ),
  );
}
