import 'package:flutter/material.dart';
import 'package:torrid/features/essay/models/label.dart';
import 'package:torrid/features/essay/models/label_tree.dart';
import 'package:torrid/features/essay/widgets/label_style.dart';

class LabelSelector extends StatefulWidget {
  final List<Label> labels;
  final List<String> selectedLabels;
  final Map<String, String> selectionHints;
  final ValueChanged<String> onToggleLabel;
  final ValueChanged<String>? onRemoveLabel;
  final Widget Function(Label)? trailingBuilder;
  final double? maxHeight;

  const LabelSelector({
    super.key,
    required this.labels,
    required this.selectedLabels,
    this.selectionHints = const {},
    required this.onToggleLabel,
    this.onRemoveLabel,
    this.trailingBuilder,
    this.maxHeight,
  });

  @override
  State<LabelSelector> createState() => _LabelSelectorState();
}

class _LabelSelectorState extends State<LabelSelector> {
  final _search = TextEditingController();
  final _expanded = <String>{};

  @override
  void initState() {
    super.initState();
    _revealSelected();
  }

  @override
  void didUpdateWidget(LabelSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.labels.isEmpty && widget.labels.isNotEmpty) _revealSelected();
  }

  void _revealSelected() {
    final byId = {for (final label in widget.labels) label.id: label};
    for (final id in widget.selectedLabels) {
      var parent = byId[id]?.parentId;
      final seen = <String>{};
      while (parent != null && seen.add(parent)) {
        _expanded.add(parent);
        parent = byId[parent]?.parentId;
      }
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final paths = labelPaths(widget.labels);
    final nodes = flattenLabels(
      widget.labels,
      expanded: _expanded,
      query: _search.text,
    );
    final parents = <String, int>{};
    for (final label in widget.labels) {
      if (label.parentId case final parent?) {
        parents[parent] = (parents[parent] ?? 0) + 1;
      }
    }
    final allExpanded = _expanded.containsAll(parents.keys);
    return LayoutBuilder(
      builder: (context, constraints) {
        final height =
            widget.maxHeight ??
            (constraints.maxHeight.isFinite ? constraints.maxHeight : 420.0);
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: height),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _search,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => FocusScope.of(context).unfocus(),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: '搜索标签或路径',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _search.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: '清除搜索',
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () => setState(_search.clear),
                              ),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.35),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: allExpanded ? '收起子标签' : '展开子标签',
                    icon: Icon(
                      allExpanded ? Icons.unfold_less : Icons.unfold_more,
                    ),
                    onPressed: parents.isEmpty || _search.text.isNotEmpty
                        ? null
                        : () => setState(() {
                            if (allExpanded) {
                              _expanded.clear();
                            } else {
                              _expanded.addAll(parents.keys);
                            }
                          }),
                  ),
                ],
              ),
              if (widget.selectedLabels.isNotEmpty)
                SizedBox(
                  height: 48,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.selectedLabels.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (context, index) {
                      final id = widget.selectedLabels[index];
                      final path = paths[id] ?? '未知标签';
                      final color = essayLabelColor(path, theme.brightness);
                      return Center(
                        child: InputChip(
                          avatar: Icon(Icons.check, size: 16, color: color),
                          backgroundColor: color.withValues(alpha: 0.1),
                          side: BorderSide.none,
                          label: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 220),
                            child: Text(
                              [
                                path,
                                if (widget.selectionHints[id] case final hint?)
                                  hint,
                              ].join(' · '),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          tooltip: path,
                          onPressed: () => widget.onToggleLabel(id),
                          onDeleted: () =>
                              (widget.onRemoveLabel ?? widget.onToggleLabel)(
                                id,
                              ),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 8),
              Flexible(
                child: nodes.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          widget.labels.isEmpty ? '还没有标签，可先新增一个' : '没有匹配的标签',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: EdgeInsets.zero,
                        itemCount: nodes.length,
                        itemBuilder: (context, index) {
                          final node = nodes[index];
                          return _buildRow(
                            node,
                            paths[node.label.id]!,
                            parents[node.label.id] ?? 0,
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRow(
    ({Label label, int depth}) node,
    String path,
    int childCount,
  ) {
    final theme = Theme.of(context);
    final label = node.label;
    final selected = widget.selectedLabels.contains(label.id);
    final expanded = _search.text.isNotEmpty || _expanded.contains(label.id);
    final color = essayLabelColor(path, theme.brightness);
    final hint = widget.selectionHints[label.id];
    return Padding(
      key: ValueKey(label.id),
      padding: EdgeInsets.only(left: node.depth.clamp(0, 5) * 12.0, bottom: 5),
      child: Material(
        color: selected
            ? color.withValues(alpha: 0.16)
            : node.depth == 0
            ? color.withValues(alpha: 0.06)
            : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: color.withValues(alpha: selected ? 0.45 : 0.12),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => widget.onToggleLabel(label.id),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Row(
              children: [
                if (childCount > 0)
                  IconButton(
                    tooltip: '${expanded ? '收起' : '展开'}「${label.name}」子标签',
                    icon: Icon(
                      expanded ? Icons.expand_more : Icons.chevron_right,
                      color: color,
                    ),
                    onPressed: _search.text.isNotEmpty
                        ? null
                        : () => setState(() {
                            if (!_expanded.remove(label.id)) {
                              _expanded.add(label.id);
                            }
                          }),
                  )
                else
                  SizedBox(
                    width: 44,
                    child: Icon(
                      label.isHiddenRoot
                          ? Icons.visibility_off_outlined
                          : Icons.label_outline,
                      color: color,
                      size: 18,
                    ),
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: node.depth == 0 || selected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        if (hint != null ||
                            childCount > 0 ||
                            label.isHiddenRoot)
                          Text(
                            hint ??
                                (label.isHiddenRoot
                                    ? '默认隐藏 · 不参与回顾'
                                    : '$childCount 个子标签'),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: color,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    '${label.essayCount}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (widget.trailingBuilder != null)
                  widget.trailingBuilder!(label)
                else
                  Checkbox(
                    value: selected,
                    activeColor: color,
                    onChanged: (_) => widget.onToggleLabel(label.id),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
