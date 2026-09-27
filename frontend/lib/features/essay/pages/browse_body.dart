import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/essay/pages/browse_all_years.dart';
import 'package:torrid/features/essay/pages/browse_part.dart';
import 'package:torrid/features/essay/providers/status_provider.dart';

class BrowseBody extends ConsumerStatefulWidget {
  const BrowseBody({super.key});

  @override
  ConsumerState<BrowseBody> createState() => BrowseBodyState();
}

class BrowseBodyState extends ConsumerState<BrowseBody> {
  late PageController _controller;
  int _currentPage = 1;
  bool _hasData = false;
  
  // 用于各页面滚动到顶部的 GlobalKey
  final GlobalKey<BrowseAllYearsState> _allYearsKey = GlobalKey();
  final Map<int, GlobalKey<BrowsePartState>> _partKeys = {};

  @override
  void initState() {
    super.initState();
    // 初始化时先创建 controller，从 page 0 开始
    _controller = PageController(initialPage: 0);
    _controller.addListener(_onPageChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onPageChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onPageChanged() {
    final page = _controller.page?.round() ?? 0;
    if (page != _currentPage) {
      setState(() {
        _currentPage = page;
      });
    }
  }

  /// 滚动当前页面到顶部
  void scrollToTop() {
    if (_currentPage == 0) {
      // "-1页" 滚动到顶部
      _allYearsKey.currentState?.scrollToTop();
    } else {
      // 各年份页面滚动到顶部
      final partKey = _partKeys[_currentPage];
      partKey?.currentState?.scrollToTop();
    }
  }

  GlobalKey<BrowsePartState> _getPartKey(int index) {
    return _partKeys.putIfAbsent(index, () => GlobalKey<BrowsePartState>());
  }

  @override
  Widget build(BuildContext context) {
    final yearSummaries = ref.watch(summariesProvider);
    
    // 当数据首次变为非空时，跳转到第一个年份页（index=1）
    if (!_hasData && yearSummaries.isNotEmpty) {
      _hasData = true;
      // 使用 addPostFrameCallback 确保 PageView 已经构建完成
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients) {
          _controller.jumpToPage(1);
          setState(() {
            _currentPage = 1;
          });
        }
      });
    }
    
    return PageView(
      controller: _controller,
      children: [
        // "-1页"：全部年份汇总
        BrowseAllYears(
          key: _allYearsKey,
          yearSummaries: yearSummaries,
        ),
        // 各年份页面
        ...yearSummaries.asMap().entries.map(
          (entry) => BrowsePart(
            key: _getPartKey(entry.key + 1),
            yearSummary: entry.value,
          ),
        ),
      ],
    );
  }
}
