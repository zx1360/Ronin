import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/read/providers/sixty_api_provider.dart';
import 'package:torrid/features/read/widgets/common.dart';

class HealthTab extends ConsumerStatefulWidget {
  const HealthTab({super.key});
  @override
  ConsumerState<HealthTab> createState() => _HealthTabState();
}

class _HealthTabState extends ConsumerState<HealthTab> {
  final _heightCtrl = TextEditingController(text: '176');
  final _weightCtrl = TextEditingController(text: '60');
  final _ageCtrl = TextEditingController(text: '24');
  String _gender = 'male';
  ({int height, int weight, int age, String gender})? _params;
  bool _ran = false;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SectionTitle(title: '身体健康分析', icon: Icons.health_and_safety),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _heightCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '身高(cm)'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _weightCtrl,
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
                  controller: _ageCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '年龄'),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _gender,
                items: const [
                  DropdownMenuItem(value: 'male', child: Text('男性')),
                  DropdownMenuItem(value: 'female', child: Text('女性')),
                ],
                onChanged: (v) => setState(() => _gender = v ?? 'male'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () async {
                  final params = (
                    height: int.tryParse(_heightCtrl.text.trim()) ?? 170,
                    weight: int.tryParse(_weightCtrl.text.trim()) ?? 60,
                    age: int.tryParse(_ageCtrl.text.trim()) ?? 24,
                    gender: _gender,
                  );
                  setState(() {
                    _params = params;
                    _ran = true;
                  });
                  ref.invalidate(healthAnalysisProvider(params));
                },
                icon: const Icon(Icons.analytics),
                label: const Text('分析'),
              ),
            ],
          ),
        ),
        if (_ran)
          Consumer(builder: (context, ref, _) {
            final async = ref.watch(healthAnalysisProvider(_params!));
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
