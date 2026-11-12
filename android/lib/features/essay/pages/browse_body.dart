import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/essay/pages/browse_list.dart';
import 'package:torrid/features/essay/providers/status_provider.dart';

class BrowseBody extends ConsumerStatefulWidget {
  const BrowseBody({super.key});

  @override
  ConsumerState<BrowseBody> createState() => BrowseBodyState();
}

class BrowseBodyState extends ConsumerState<BrowseBody> {
  final _controller = PageController();
  final _currentPage = ValueNotifier(0);
  bool _hasData = false;

  // 用于各页面滚动到顶部的 GlobalKey
  final GlobalKey<BrowseListState> _allYearsKey = GlobalKey();
  final Map<String, GlobalKey<BrowseListState>> _partKeys = {};
  List<String> _years = [];

  @override
  void dispose() {
    _controller.dispose();
    _currentPage.dispose();
    super.dispose();
  }

  /// 滚动当前页面到顶部
  void scrollToTop() {
    final page = _currentPage.value;
    if (page == 0) {
      _allYearsKey.currentState?.scrollToTop();
    } else {
      final partKey = page <= _years.length
          ? _partKeys[_years[page - 1]]
          : null;
      partKey?.currentState?.scrollToTop();
    }
  }

  GlobalKey<BrowseListState> _getPartKey(String year) {
    return _partKeys.putIfAbsent(year, () => GlobalKey<BrowseListState>());
  }

  void _goToPage(int page) {
    final distance = (page - _currentPage.value).abs();
    if (!_controller.hasClients || distance == 0) return;
    if (distance > 1) {
      _controller.jumpToPage(page);
      return;
    }
    _controller.animateToPage(
      page,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _jumpAfterLayout(int page) {
    final years = _years;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients || !identical(_years, years)) {
        return;
      }
      _controller.jumpToPage(page);
      _currentPage.value = page;
      _hasData = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentPage = _currentPage.value;
    final activeYear = currentPage > 0 && currentPage <= _years.length
        ? _years[currentPage - 1]
        : null;
    _years = ref.watch(browseYearsProvider);
    _partKeys.removeWhere((year, _) => !_years.contains(year));

    // 当数据首次变为非空时，跳转到第一个年份页（index=1）
    if (!_hasData && _years.isNotEmpty) {
      _jumpAfterLayout(1);
    } else if (activeYear != null) {
      final index = _years.indexOf(activeYear);
      final newPage = index < 0
          ? currentPage.clamp(0, _years.length)
          : index + 1;
      if (newPage != currentPage) _jumpAfterLayout(newPage);
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
                onPressed: () => _goToPage(0),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ValueListenableBuilder<int>(
                  valueListenable: _currentPage,
                  builder: (context, page, _) => DropdownButton<int>(
                    value: page > 0 && page <= _years.length ? page : null,
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
                      if (page != null) _goToPage(page);
                    },
                  ),
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
            onPageChanged: (page) => _currentPage.value = page,
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
