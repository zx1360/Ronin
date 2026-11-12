import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torrid/app/theme/theme_book.dart';
import 'package:torrid/features/essay/models/essay.dart';
import 'package:torrid/features/essay/models/label.dart';
import 'package:torrid/features/essay/models/year_summary.dart';
import 'package:torrid/features/essay/pages/browse_body.dart';
import 'package:torrid/features/essay/pages/browse_list.dart';
import 'package:torrid/features/essay/pages/browse_page.dart';
import 'package:torrid/features/essay/pages/drafts_page.dart';
import 'package:torrid/features/essay/pages/essay_label_suggestions_page.dart';
import 'package:torrid/features/essay/pages/year_overview_page.dart';
import 'package:torrid/features/essay/providers/essay_data_provider.dart';
import 'package:torrid/features/essay/providers/setting_provider.dart';
import 'package:torrid/features/essay/providers/status_provider.dart';
import 'package:torrid/features/essay/services/essay_draft_store.dart';
import 'package:torrid/features/essay/widgets/browse/essay_card.dart';
import 'package:torrid/features/essay/widgets/browse/year_summary_card.dart';
import 'package:torrid/features/essay/widgets/overview/writing_trend_chart.dart';

Essay _essay(String id, List<String> labels, {int index = 0}) => Essay(
  id: id,
  date: DateTime(2026, 3, 31 - index),
  title: '随笔 $id',
  wordCount: 2,
  content: '正文 $id',
  imgs: [],
  labels: labels,
  messages: [],
);

final class _YearLoads extends ProviderObserver {
  final initial = <String, Object?>{};

  @override
  void didAddProvider(ProviderObserverContext context, Object? value) {
    if (context.provider case YearEssaysProvider(argument: final String year)) {
      initial[year] = value;
    }
  }
}

void main() {
  testWidgets('趋势图只显示有随笔的月份，柱高和点高分别对应字数和篇数', (tester) async {
    final summary = YearSummary.fromEssays('2026', [
      _essay('oct-1', []).copyWith(date: DateTime(2026, 10), wordCount: 30),
      _essay('feb', []).copyWith(date: DateTime(2026, 2), wordCount: 200),
      _essay('oct-2', []).copyWith(date: DateTime(2026, 10, 2), wordCount: 20),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WritingTrendChart(periods: summary.monthSummaries),
        ),
      ),
    );

    expect(find.text('字数'), findsOneWidget);
    expect(find.text('篇数'), findsOneWidget);
    final february = find.byTooltip('2月\n1 篇 · 200 字');
    final october = find.byTooltip('10月\n2 篇 · 50 字');
    expect(find.byType(Tooltip), findsNWidgets(2));
    expect(
      tester.getCenter(february).dx,
      lessThan(tester.getCenter(october).dx),
    );

    Finder mark(Finder period, BoxShape shape) => find.descendant(
      of: period,
      matching: find.byWidgetPredicate((widget) {
        final decoration = widget is Container ? widget.decoration : null;
        return decoration is BoxDecoration && decoration.shape == shape;
      }),
    );
    expect(
      tester.getSize(mark(february, BoxShape.rectangle)).height,
      greaterThan(tester.getSize(mark(october, BoxShape.rectangle)).height),
    );
    expect(
      tester.getCenter(mark(october, BoxShape.circle)).dy,
      lessThan(tester.getCenter(mark(february, BoxShape.circle)).dy),
    );
  });

  testWidgets('320dp 随笔两级概览容纳 12 个月，入口和写作按钮可直接使用', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final essays = [
      for (var month = 1; month <= 12; month++)
        _essay('month-$month', []).copyWith(date: DateTime(2026, month)),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          labelStreamProvider.overrideWith((_) => Stream.value([])),
          essayStreamProvider.overrideWith((_) => Stream.value(essays)),
          essayDraftsProvider.overrideWith((_) => Stream.value([])),
        ],
        child: MaterialApp(
          theme: AppTheme.bookTheme(),
          home: const EssayBrowsePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(
      appBar.actions!.whereType<IconButton>().map((button) => button.tooltip),
      ['AI 标签建议', '本机草稿', '浏览设置'],
    );
    final write = find.byType(FloatingActionButton);
    expect(
      tester.widget<FloatingActionButton>(write).shape,
      isA<StadiumBorder>(),
    );
    expect(
      tester.getRect(write).contains(tester.getBottomRight(find.text('写随笔'))),
      isTrue,
    );

    await tester.tap(find.byTooltip('本机草稿'));
    await tester.pumpAndSettle();
    expect(find.byType(EssayDraftsPage), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('AI 标签建议'));
    await tester.pumpAndSettle();
    expect(find.byType(EssayLabelSuggestionsPage), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    void expectMonthsInOneRow() {
      final chart = find.byType(WritingTrendChart);
      final chartRect = tester.getRect(chart);
      final ticks = [
        for (var month = 1; month <= 12; month++)
          tester.getRect(
            find.descendant(of: chart, matching: find.text('$month')),
          ),
      ];
      for (final tick in ticks) {
        expect(tick.top, closeTo(ticks.first.top, 1));
        expect(tick.left, greaterThanOrEqualTo(chartRect.left));
        expect(tick.right, lessThanOrEqualTo(chartRect.right));
      }
      expect(ticks.last.left, greaterThan(ticks.first.right));
    }

    expectMonthsInOneRow();
    await tester.tap(
      find.descendant(
        of: find.byType(YearSummaryCard),
        matching: find.text('2026 年'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(YearOverviewPage), findsOneWidget);
    expectMonthsInOneRow();
    expect(tester.takeException(), isNull);
  });

  testWidgets('跨多年切换直接显示目标列表，不构建途经的年份页', (tester) async {
    final loads = _YearLoads();
    final essays = [
      for (var year = 2026; year >= 2019; year--)
        _essay('$year', []).copyWith(date: DateTime(year, 1, 1)),
    ];
    await tester.pumpWidget(
      ProviderScope(
        observers: [loads],
        overrides: [
          labelStreamProvider.overrideWith((_) => Stream.value([])),
          essayStreamProvider.overrideWith((_) => Stream.value(essays)),
        ],
        child: const MaterialApp(home: Scaffold(body: BrowseBody())),
      ),
    );
    await tester.pumpAndSettle();
    final dropdown = find.byType(DropdownButton<int>);
    final pageView = find.byType(PageView);
    final initialPageView = tester.widget<PageView>(pageView);
    expect(tester.widget<DropdownButton<int>>(dropdown).value, 1);
    loads.initial.clear();

    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('2019 年').hitTestable().last);
    for (var frame = 0; frame < 16; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();

    expect(tester.widget<DropdownButton<int>>(dropdown).value, 8);
    expect(tester.widget<PageView>(pageView), same(initialPageView));
    expect(loads.initial.keys, ['2019']);
    expect(loads.initial['2019'], isA<AsyncData<List<Essay>>>());
    expect(find.text('随笔 2019').hitTestable(), findsOneWidget);
  });

  test('标签包含与排除同时生效，默认隐藏子树', () async {
    final labels = [
      Label(id: 'root', name: '父级', essayCount: 0),
      Label(id: 'child', name: '子级', parentId: 'root', essayCount: 0),
      Label(id: 'skip', name: '排除项', essayCount: 0),
      Label.hidden(),
      Label(id: 'private', name: '私有', parentId: Label.hiddenId, essayCount: 0),
    ];
    final container = ProviderContainer.test(
      overrides: [
        labelStreamProvider.overrideWith((_) => Stream.value(labels)),
        essayStreamProvider.overrideWith(
          (_) => Stream.value([
            _essay('direct', ['root']),
            _essay('child', ['child']),
            _essay('skip', ['child', 'skip']),
            _essay('hidden', ['child', 'private']),
            _essay('unrelated', ['skip']).copyWith(date: DateTime(2024, 1)),
            _essay('hidden-year', [
              'private',
            ]).copyWith(date: DateTime(2025, 1)),
          ]),
        ),
      ],
    );
    container.listen(filteredEssaysProvider, (_, _) {});
    final settings = container.read(browseManagerProvider.notifier);
    settings.toggleLabel('skip', hasChildren: false, exclude: true);
    expect(
      (await container.read(
        filteredEssaysProvider.future,
      )).map((essay) => essay.id),
      ['direct', 'child'],
    );
    settings.toggleLabel('root', hasChildren: true, exclude: false);
    expect(
      (await container.read(
        filteredEssaysProvider.future,
      )).map((essay) => essay.id),
      ['direct', 'child'],
    );
    settings.toggleLabel('root', hasChildren: true, exclude: false);
    expect(
      (await container.read(
        filteredEssaysProvider.future,
      )).map((essay) => essay.id),
      ['direct'],
    );
    expect(container.read(browseYearsProvider), ['2026', '2024']);
    settings.setShowHidden(true, {Label.hiddenId, 'private'});
    expect(container.read(browseYearsProvider), ['2026', '2025', '2024']);
  });

  testWidgets('详情编辑标签返回时保留随笔列表的滚动位置', (tester) async {
    final updates = StreamController<List<Essay>>.broadcast();
    addTearDown(updates.close);
    final labels = [Label(id: 'one', name: '标签', essayCount: 0)];
    final essays = List.generate(30, (i) => _essay('$i', ['one'], index: i));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          labelStreamProvider.overrideWith((_) => Stream.value(labels)),
          essayStreamProvider.overrideWith((_) async* {
            yield essays;
            yield* updates.stream;
          }),
          essayByIdProvider.overrideWith(
            (_, id) =>
                Stream.value(essays.firstWhere((essay) => essay.id == id)),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: BrowseList(year: '-1')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final list = find.byType(ListView);
    await tester.drag(list, const Offset(0, -1100));
    await tester.pumpAndSettle();
    final offset = tester.widget<ListView>(list).controller!.offset;
    expect(offset, greaterThan(400));
    final visibleCard = find.byType(EssayCard).hitTestable().first;
    final target = tester.widget<EssayCard>(visibleCard).essay;
    await tester.tap(visibleCard);
    await tester.pumpAndSettle();
    expect(find.text('随笔详情'), findsOneWidget);
    updates.add([
      for (final essay in essays)
        if (essay.id != target.id) essay,
    ]);
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      tester.widget<ListView>(list).controller!.offset,
      closeTo(offset, 1),
    );
  });
}
