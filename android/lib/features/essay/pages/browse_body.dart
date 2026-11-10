import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/essay/pages/browse_list.dart';
import 'package:torrid/features/essay/providers/box_provider.dart';
import 'package:torrid/features/essay/providers/setting_provider.dart';
import 'package:torrid/features/essay/providers/status_provider.dart';

class BrowseBody extends ConsumerStatefulWidget {
  const BrowseBody({super.key});

  @override
  ConsumerState<BrowseBody> createState() => BrowseBodyState();
}

class BrowseBodyState extends ConsumerState<BrowseBody> {
  final _controller = PageController();
  int _currentPage = 0;
  bool _hasData = false;

  // 用于各页面滚动到顶部的 GlobalKey
  final GlobalKey<BrowseListState> _allYearsKey = GlobalKey();
  final Map<String, GlobalKey<BrowseListState>> _partKeys = {};
  List<String> _years = [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 滚动当前页面到顶部
  void scrollToTop() {
    if (_currentPage == 0) {
      _allYearsKey.currentState?.scrollToTop();
    } else {
      final partKey = _currentPage <= _years.length
          ? _partKeys[_years[_currentPage - 1]]
          : null;
      partKey?.currentState?.scrollToTop();
    }
  }

  GlobalKey<BrowseListState> _getPartKey(String year) {
    return _partKeys.putIfAbsent(year, () => GlobalKey<BrowseListState>());
  }

  @override
  Widget build(BuildContext context) {
    final years = ref
        .watch(summariesProvider)
        .map((summary) => summary.year)
        .toSet();
    if (ref.watch(browseManagerProvider).showHidden) {
      final essays =
          ref.watch(essayStreamProvider).valueOrNull ??
          ref.read(essayBoxProvider).values;
      years.addAll(essays.map((essay) => essay.year.toString()));
    }
    _years = years.toList()..sort((a, b) => b.compareTo(a));
    _partKeys.removeWhere((year, _) => !_years.contains(year));

    // 当数据首次变为非空时，跳转到第一个年份页（index=1）
    if (!_hasData && _years.isNotEmpty) {
      _hasData = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients && _years.isNotEmpty) {
          _controller.jumpToPage(1);
          setState(() {
            _currentPage = 1;
          });
        }
      });
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: Row(
            children: [
              TextButton.icon(
                icon: const Icon(Icons.dashboard_outlined, size: 18),
                label: const Text('总览'),
                onPressed: () => _controller.animateToPage(
                  0,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButton<int>(
                  value: _currentPage > 0 && _currentPage <= _years.length
                      ? _currentPage
                      : null,
                  hint: const Text('选择年份'),
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  items: [
                    for (var i = 0; i < _years.length; i++)
                      DropdownMenuItem(
                        value: i + 1,
                        child: Text('${_years[i]} 年'),
                      ),
                  ],
                  onChanged: (page) {
                    if (page != null) {
                      _controller.animateToPage(
                        page,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      );
                    }
                  },
                ),
              ),
              IconButton(
                tooltip: '回到顶部',
                icon: const Icon(Icons.vertical_align_top, size: 20),
                onPressed: scrollToTop,
              ),
            ],
          ),
        ),
        Expanded(
          child: PageView(
            controller: _controller,
            onPageChanged: (page) => setState(() => _currentPage = page),
            children: [
              // "-1页"：全部年份汇总
              BrowseList(key: _allYearsKey, year: '-1'),
              // 各年份页面
              ..._years.map(
                (year) => BrowseList(key: _getPartKey(year), year: year),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
