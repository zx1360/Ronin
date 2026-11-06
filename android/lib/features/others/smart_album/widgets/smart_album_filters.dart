import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:torrid/core/utils/serialization.dart';
import 'package:torrid/features/others/immich/widgets/immich_tag_picker.dart';
import 'package:torrid/features/others/smart_album/providers/smart_album_providers.dart';

Future<AlbumSearchFilters?> showAlbumSearchFilters(
  BuildContext context,
  AlbumSearchFilters initial,
) => showModalBottomSheet<AlbumSearchFilters>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _SearchFiltersSheet(initial: initial),
);

class _SearchFiltersSheet extends StatefulWidget {
  final AlbumSearchFilters initial;

  const _SearchFiltersSheet({required this.initial});

  @override
  State<_SearchFiltersSheet> createState() => _SearchFiltersSheetState();
}

class _SearchFiltersSheetState extends State<_SearchFiltersSheet> {
  late DateTimeRange? _dates = widget.initial.dates;
  late String _mimeType = widget.initial.mimeType;
  late Set<String> _tagIds = widget.initial.tagIds;

  @override
  Widget build(BuildContext context) {
    final dates = _dates;
    final changed =
        dates != widget.initial.dates ||
        _mimeType != widget.initial.mimeType ||
        !setEquals(_tagIds, widget.initial.tagIds);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('检索筛选'),
              trailing: TextButton(
                onPressed: dates == null && _mimeType.isEmpty && _tagIds.isEmpty
                    ? null
                    : () => setState(() {
                        _dates = null;
                        _mimeType = '';
                        _tagIds = const {};
                      }),
                child: const Text('重置'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: '', label: Text('不限类型')),
                  ButtonSegment(value: 'image', label: Text('照片')),
                  ButtonSegment(value: 'video', label: Text('视频')),
                ],
                selected: {_mimeType},
                onSelectionChanged: (values) =>
                    setState(() => _mimeType = values.single),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.date_range_outlined),
              title: const Text('拍摄日期'),
              subtitle: Text(
                dates == null
                    ? '不限日期'
                    : '${dateToJson(dates.start)} 至 ${dateToJson(dates.end)}',
              ),
              trailing: dates == null
                  ? const Icon(Icons.chevron_right)
                  : IconButton(
                      tooltip: '清除日期',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _dates = null),
                    ),
              onTap: _pickDates,
            ),
            ListTile(
              leading: const Icon(Icons.label_outline),
              title: const Text('人工标签'),
              subtitle: Text(
                _tagIds.isEmpty ? '不限标签' : '已选 ${_tagIds.length} 个，含子标签',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickTags,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: FilledButton(
                onPressed: changed
                    ? () => Navigator.pop(
                        context,
                        AlbumSearchFilters(
                          dates: dates,
                          mimeType: _mimeType,
                          tagIds: _tagIds,
                        ),
                      )
                    : null,
                child: const Text('应用筛选'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDates() async {
    final dates = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1),
      lastDate: DateTime.now(),
      initialDateRange: _dates,
      helpText: '选择拍摄日期',
      saveText: '确定',
      cancelText: '取消',
      confirmText: '确定',
      fieldStartLabelText: '开始日期',
      fieldEndLabelText: '结束日期',
      builder: (context, child) => DatePickerTheme(
        data: DatePickerTheme.of(context).copyWith(
          rangePickerHeaderHeadlineStyle: Theme.of(
            context,
          ).textTheme.titleMedium,
        ),
        child: child!,
      ),
    );
    if (mounted && dates != null) setState(() => _dates = dates);
  }

  Future<void> _pickTags() async {
    final ids = await showImmichTagPicker(
      context,
      title: '匹配任一标签',
      initialChecked: _tagIds,
    );
    if (mounted && ids != null) setState(() => _tagIds = ids);
  }
}
