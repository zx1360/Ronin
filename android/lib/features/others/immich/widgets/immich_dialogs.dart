import 'package:flutter/material.dart';

Future<DateTime?> showImmichMonthPicker(
  BuildContext context,
  DateTime initial,
) => showDialog<DateTime>(
  context: context,
  builder: (_) => _MonthPickerDialog(initial: initial),
);

class _MonthPickerDialog extends StatefulWidget {
  final DateTime initial;

  const _MonthPickerDialog({required this.initial});

  @override
  State<_MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<_MonthPickerDialog> {
  late int _year = widget.initial.year.clamp(1, 9998);
  late final int _lastYear = DateTime.now().year.clamp(_year, 9998);
  bool _pickingYear = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('跳到月份'),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton.icon(
              onPressed: () => setState(() => _pickingYear = !_pickingYear),
              icon: Icon(_pickingYear ? Icons.expand_less : Icons.expand_more),
              label: Text('$_year年'),
            ),
            SizedBox(
              height: 180,
              child: _pickingYear
                  ? YearPicker(
                      firstDate: DateTime(1),
                      lastDate: DateTime(_lastYear, 12, 31),
                      selectedDate: DateTime(_year),
                      onChanged: (date) => setState(() {
                        _year = date.year;
                        _pickingYear = false;
                      }),
                    )
                  : GridView.count(
                      crossAxisCount: 4,
                      mainAxisExtent: 52,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        for (var month = 1; month <= 12; month++)
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(context, DateTime(_year, month)),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                            ),
                            child: Text('$month月'),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ],
    );
  }
}

Future<bool> confirmAlbumDeletion(BuildContext context, int count) =>
    showImmichConfirmDialog(
      context,
      title: '标记待删除',
      message:
          '将 $count 项标记为待删除，捆绑成员会随主文件一同标记。'
          '在桌面端执行处理前，可开启「含待删除」恢复。',
      confirmText: '标记待删除',
      danger: true,
    );

/// 确认对话框; 返回是否确认
Future<bool> showImmichConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmText = '确定',
  bool danger = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('取消'),
        ),
        FilledButton(
          style: danger
              ? FilledButton.styleFrom(backgroundColor: Colors.red)
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmText),
        ),
      ],
    ),
  );
  return result == true;
}
