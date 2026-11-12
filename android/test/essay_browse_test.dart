import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torrid/features/essay/models/essay.dart';
import 'package:torrid/features/essay/models/label.dart';
import 'package:torrid/features/essay/pages/browse_list.dart';
import 'package:torrid/features/essay/providers/essay_data_provider.dart';
import 'package:torrid/features/essay/providers/setting_provider.dart';
import 'package:torrid/features/essay/providers/status_provider.dart';
import 'package:torrid/features/essay/widgets/browse/essay_card.dart';

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

void main() {
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
            _essay('unrelated', ['skip']),
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
