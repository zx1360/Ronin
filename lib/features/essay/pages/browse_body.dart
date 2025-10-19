import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/essay/pages/browse_part.dart';
import 'package:torrid/features/essay/providers/status_provider.dart';

class BrowseBody extends ConsumerStatefulWidget {
  const BrowseBody({super.key});

  @override
  ConsumerState<BrowseBody> createState() => _BrowseBodyState();
}

class _BrowseBodyState extends ConsumerState<BrowseBody> {
  final PageController controller = PageController();

  @override
  Widget build(BuildContext context) {
      // 获取到yearSummaries数据之后, 构建PageView, 左右切换不同年份的随笔.
      // TODO: ⭐设置"-1"页, 展示所有年份的.  (实际上就是控制从第二页开始展示).
    final yearSummaries = ref.watch(summariesProvider);
    return PageView(
      controller: controller,
      children: yearSummaries
          .map((year) => EssayBrowsePart(yearSummary: year))
          .toList(),
    );
  }
}
