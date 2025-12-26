import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/read/providers/sixty_api_provider.dart';
import 'package:torrid/features/read/widgets/common.dart';

class FabingTab extends ConsumerStatefulWidget {
  const FabingTab({super.key});
  @override
  ConsumerState<FabingTab> createState() => _FabingTabState();
}

class _FabingTabState extends ConsumerState<FabingTab> {
  final _nameCtrl = TextEditingController();
  @override
  Widget build(BuildContext context) {
    final name = _nameCtrl.text.trim();
    final async = ref.watch(fabingProvider(name.isEmpty ? null : name));
    return ListView(
      children: [
        const SectionTitle(title: '随机发病文学', icon: Icons.auto_stories),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(hintText: '替换的人名（可选），默认：主人'),
                  onSubmitted: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => setState(() {}),
                child: const Text('生成'),
              ),
            ],
          ),
        ),
        async.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView('生成失败：$e'),
          data: (data) => Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(data['saying'] ?? ''),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
