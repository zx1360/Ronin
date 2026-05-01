import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 添加/编辑倒计时器对话框
class TimerEditDialog extends StatefulWidget {
  final String? initialName;
  final int? initialSeconds;
  final bool isEditing;

  const TimerEditDialog({
    super.key,
    this.initialName,
    this.initialSeconds,
    this.isEditing = false,
  });

  @override
  State<TimerEditDialog> createState() => _TimerEditDialogState();
}

class _TimerEditDialogState extends State<TimerEditDialog> {
  late TextEditingController _nameController;
  late TextEditingController _minutesController;
  late TextEditingController _secondsController;
  
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    
    final totalSeconds = widget.initialSeconds ?? 60;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    
    _minutesController = TextEditingController(text: minutes.toString());
    _secondsController = TextEditingController(text: seconds.toString());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _minutesController.dispose();
    _secondsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(widget.isEditing ? '编辑倒计时' : '添加倒计时'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 名称输入
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '名称',
                  hintText: '输入倒计时名称',
                  prefixIcon: Icon(Icons.label_outline),
                  border: OutlineInputBorder(),
                ),
                maxLength: 20,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '请输入名称';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // 时间输入
              Text(
                '时长设置',
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  // 分钟
                  Expanded(
                    child: TextFormField(
                      controller: _minutesController,
                      decoration: const InputDecoration(
                        labelText: '分钟',
                        suffixText: '分',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(2),
                      ],
                      validator: (value) {
                        final minutes = int.tryParse(value ?? '0') ?? 0;
                        final seconds = int.tryParse(_secondsController.text) ?? 0;
                        if (minutes == 0 && seconds == 0) {
                          return '时长不能为0';
                        }
                        if (minutes > 60) {
                          return '最多60分钟';
                        }
                        return null;
                      },
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(':', style: TextStyle(fontSize: 24)),
                  ),
                  // 秒
                  Expanded(
                    child: TextFormField(
                      controller: _secondsController,
                      decoration: const InputDecoration(
                        labelText: '秒',
                        suffixText: '秒',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(2),
                      ],
                      validator: (value) {
                        final seconds = int.tryParse(value ?? '0') ?? 0;
                        if (seconds > 59) {
                          return '最多59秒';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '提示：最大支持60分钟',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.outline,
                ),
              ),
              const SizedBox(height: 16),
              // 快捷时间选择
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildQuickTimeChip('30秒', 0, 30),
                  _buildQuickTimeChip('1分钟', 1, 0),
                  _buildQuickTimeChip('3分钟', 3, 0),
                  _buildQuickTimeChip('5分钟', 5, 0),
                  _buildQuickTimeChip('10分钟', 10, 0),
                  _buildQuickTimeChip('15分钟', 15, 0),
                  _buildQuickTimeChip('30分钟', 30, 0),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _onConfirm,
          child: Text(widget.isEditing ? '保存' : '添加'),
        ),
      ],
    );
  }

  /// 构建快捷时间选择芯片
  Widget _buildQuickTimeChip(String label, int minutes, int seconds) {
    return ActionChip(
      label: Text(label),
      onPressed: () {
        setState(() {
          _minutesController.text = minutes.toString();
          _secondsController.text = seconds.toString();
        });
      },
    );
  }

  /// 确认回调
  void _onConfirm() {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final minutes = int.tryParse(_minutesController.text) ?? 0;
    final seconds = int.tryParse(_secondsController.text) ?? 0;
    final totalSeconds = (minutes * 60 + seconds).clamp(1, 3600);

    Navigator.pop(context, {
      'name': name,
      'totalSeconds': totalSeconds,
    });
  }
}

/// 显示添加/编辑对话框
Future<Map<String, dynamic>?> showTimerEditDialog(
  BuildContext context, {
  String? initialName,
  int? initialSeconds,
  bool isEditing = false,
}) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (context) => TimerEditDialog(
      initialName: initialName,
      initialSeconds: initialSeconds,
      isEditing: isEditing,
    ),
  );
}
