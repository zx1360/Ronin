import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/read/providers/sixty_api_provider.dart';
import 'package:torrid/features/read/widgets/common.dart';

class UtilitiesView extends ConsumerStatefulWidget {
  const UtilitiesView({super.key});
  @override
  ConsumerState<UtilitiesView> createState() => _UtilitiesViewState();
}

class _UtilitiesViewState extends ConsumerState<UtilitiesView> {
  final _lyricCtrl = TextEditingController();
  final _baikeCtrl = TextEditingController();
  final _heightCtrl = TextEditingController(text: '176');
  final _weightCtrl = TextEditingController(text: '60');
  final _ageCtrl = TextEditingController(text: '24');
  String _gender = 'male';

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: '摸鱼日报'),
              Tab(text: '歌词搜索'),
              Tab(text: '百科词条'),
              Tab(text: '健康分析'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _MoyuTab(ref: ref),
                _LyricTab(ref: ref, ctrl: _lyricCtrl),
                _BaikeTab(ref: ref, ctrl: _baikeCtrl),
                _HealthTab(
                  ref: ref,
                  heightCtrl: _heightCtrl,
                  weightCtrl: _weightCtrl,
                  ageCtrl: _ageCtrl,
                  gender: _gender,
                  onGenderChanged: (g) => setState(() => _gender = g),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MoyuTab extends ConsumerWidget {
  final WidgetRef ref;
  const _MoyuTab({required this.ref});
  @override
  Widget build(BuildContext context, WidgetRef _) {
    final async = ref.watch(moyuDailyProvider);
    return async.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView('摸鱼日报加载失败：$e'),
      data: (data) {
        final quote = data['moyuQuote'] as String?;
        final progress = data['progress'] as Map<String, dynamic>?;
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(moyuDailyProvider),
          child: ListView(
            children: [
              const SectionTitle(title: '今日进度', icon: Icons.timeline),
              if (progress != null) ...[
                _progressRow(context, '周进度', progress['week'] as Map<String, dynamic>?),
                _progressRow(context, '月进度', progress['month'] as Map<String, dynamic>?),
                _progressRow(context, '年进度', progress['year'] as Map<String, dynamic>?),
              ],
              const SectionTitle(title: '摸鱼金句', icon: Icons.format_quote),
              if (quote != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    child: ListTile(
                      title: Text(quote),
                      trailing: IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () => Clipboard.setData(ClipboardData(text: quote)),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _progressRow(BuildContext context, String label, Map<String, dynamic>? p) {
    if (p == null) return const SizedBox.shrink();
    final percent = ((p['percentage'] ?? 0) as num).toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: percent / 100),
          const SizedBox(height: 4),
          Text('已完成：${percent.toStringAsFixed(0)}%'),
        ],
      ),
    );
  }
}

class _LyricTab extends ConsumerWidget {
  final WidgetRef ref;
  final TextEditingController ctrl;
  const _LyricTab({required this.ref, required this.ctrl});
  @override
  Widget build(BuildContext context, WidgetRef _) {
    return ListView(
      children: [
        const SectionTitle(title: '搜索歌词', icon: Icons.music_note),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: ctrl,
                  decoration: const InputDecoration(hintText: '输入歌曲名，例如：小宇'),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => ref.invalidate(lyricSearchProvider(ctrl.text.trim())),
                icon: const Icon(Icons.search),
                label: const Text('搜索'),
              ),
            ],
          ),
        ),
        if (ctrl.text.trim().isNotEmpty)
          Consumer(builder: (context, ref, _) {
            final async = ref.watch(lyricSearchProvider(ctrl.text.trim()));
            return async.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView('歌词搜索失败：$e'),
              data: (data) {
                final formatted = data['formatted'] as String?;
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: SelectableText(
                        formatted ?? '未找到歌词',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                );
              },
            );
          }),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _BaikeTab extends ConsumerWidget {
  final WidgetRef ref;
  final TextEditingController ctrl;
  const _BaikeTab({required this.ref, required this.ctrl});
  @override
  Widget build(BuildContext context, WidgetRef _) {
    return ListView(
      children: [
        const SectionTitle(title: '百度百科词条', icon: Icons.book),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: ctrl,
                  decoration: const InputDecoration(hintText: '输入关键词，例如：西游记'),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => ref.invalidate(baikeEntryProvider(ctrl.text.trim())),
                icon: const Icon(Icons.search),
                label: const Text('检索'),
              ),
            ],
          ),
        ),
        if (ctrl.text.trim().isNotEmpty)
          Consumer(builder: (context, ref, _) {
            final async = ref.watch(baikeEntryProvider(ctrl.text.trim()));
            return async.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView('百科检索失败：$e'),
              data: (data) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (data['cover'] != null)
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: Image.network(data['cover'] as String, fit: BoxFit.cover),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(data['title'] ?? '', style: Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 8),
                              Text(data['description'] ?? '', style: Theme.of(context).textTheme.bodyMedium),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: () => Clipboard.setData(ClipboardData(text: (data['link'] ?? '') as String)),
                                icon: const Icon(Icons.link),
                                label: const Text('复制百科链接'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _HealthTab extends ConsumerWidget {
  final WidgetRef ref;
  final TextEditingController heightCtrl;
  final TextEditingController weightCtrl;
  final TextEditingController ageCtrl;
  final String gender;
  final ValueChanged<String> onGenderChanged;
  const _HealthTab({
    required this.ref,
    required this.heightCtrl,
    required this.weightCtrl,
    required this.ageCtrl,
    required this.gender,
    required this.onGenderChanged,
  });
  @override
  Widget build(BuildContext context, WidgetRef _) {
    return ListView(
      children: [
        const SectionTitle(title: '身体健康分析', icon: Icons.health_and_safety),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: heightCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '身高(cm)'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: weightCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '体重(kg)'),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: ageCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '年龄'),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: gender,
                items: const [
                  DropdownMenuItem(value: 'male', child: Text('男性')),
                  DropdownMenuItem(value: 'female', child: Text('女性')),
                ],
                onChanged: (v) => onGenderChanged(v ?? 'male'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () {
                  final params = (
                    height: int.tryParse(heightCtrl.text.trim()) ?? 170,
                    weight: int.tryParse(weightCtrl.text.trim()) ?? 60,
                    age: int.tryParse(ageCtrl.text.trim()) ?? 24,
                    gender: gender,
                  );
                  ref.invalidate(healthAnalysisProvider(params));
                },
                icon: const Icon(Icons.analytics),
                label: const Text('分析'),
              ),
            ],
          ),
        ),
        Consumer(builder: (context, ref, _) {
          final params = (
            height: int.tryParse(heightCtrl.text.trim()) ?? 170,
            weight: int.tryParse(weightCtrl.text.trim()) ?? 60,
            age: int.tryParse(ageCtrl.text.trim()) ?? 24,
            gender: gender,
          );
          final async = ref.watch(healthAnalysisProvider(params));
          return async.when(
            loading: () => const LoadingView(),
            error: (e, _) => ErrorView('健康分析失败：$e'),
            data: (data) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _kv(context, data['basic_info'] as Map<String, dynamic>?, '基本信息'),
                        _kv(context, data['bmi'] as Map<String, dynamic>?, 'BMI'),
                        _kv(context, data['weight_assessment'] as Map<String, dynamic>?, '体重评估'),
                        _kv(context, data['metabolism'] as Map<String, dynamic>?, '代谢'),
                        _kv(context, data['body_surface_area'] as Map<String, dynamic>?, '体表面积'),
                        _kv(context, data['body_fat'] as Map<String, dynamic>?, '体脂'),
                        const SizedBox(height: 8),
                        Text('建议与提示', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        ...((data['health_advice']?['health_tips'] as List<dynamic>? ?? [])
                            .map((e) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Text('• ${e.toString()}'),
                                ))),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        }),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _kv(BuildContext ctx, Map<String, dynamic>? m, String title) {
    if (m == null) return const SizedBox.shrink();
    final entries = m.entries.toList();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(ctx).textTheme.titleMedium),
          const SizedBox(height: 4),
          ...entries.map((e) => Text('${e.key}: ${e.value}')),
        ],
      ),
    );
  }
}
