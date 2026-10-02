import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/app/theme/theme_book.dart';
import 'package:torrid/features/chat/models/chat_options.dart';
import 'package:torrid/features/chat/providers/chat_providers.dart';
import 'package:torrid/features/chat/services/chat_api_service.dart';

/// 对话设置：上下文大小、思考深度、采样温度、模型卸载超时。
///
/// "卸载超时"提供开关：关闭时用后端设定的默认值，打开时用输入框里的秒数。
class ChatSettingsPage extends ConsumerStatefulWidget {
  const ChatSettingsPage({super.key});

  @override
  ConsumerState<ChatSettingsPage> createState() => _ChatSettingsPageState();
}

class _ChatSettingsPageState extends ConsumerState<ChatSettingsPage> {
  final TextEditingController _keepAliveController = TextEditingController();

  /// 服务端默认值（读 /API/ai/status 的 ollama 段，失败则用本地缺省）。
  ChatServerInfo? _server;

  @override
  void initState() {
    super.initState();
    _keepAliveController.text =
        ref.read(chatOptionsControllerProvider).keepAliveSeconds.toString();
    _loadServerInfo();
  }

  @override
  void dispose() {
    _keepAliveController.dispose();
    super.dispose();
  }

  Future<void> _loadServerInfo() async {
    try {
      final info = await ref.read(chatServerInfoProvider.future);
      if (!mounted) return;
      setState(() => _server = info);
      _dropUnavailableModel(info);
    } catch (_) {
      // 服务端不可达时只影响"默认值/已安装"的展示，不影响设置项本身
    }
  }

  /// 本地保存的模型可能已被删掉（后端 ollama rm）：清空表示"跟随后端"，
  /// 否则每一轮对话都会因该模型不可用而失败。
  void _dropUnavailableModel(ChatServerInfo info) {
    final options = ref.read(chatOptionsControllerProvider);
    if (options.model.isEmpty || info.candidates.isEmpty) return;
    for (final candidate in info.candidates) {
      if (candidate.installed &&
          candidate.model.toLowerCase() == options.model.toLowerCase()) {
        return;
      }
    }
    ref
        .read(chatOptionsControllerProvider.notifier)
        .update(options.copyWith(model: ''));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${options.model} 已不可用，已切回跟随后端')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final options = ref.watch(chatOptionsControllerProvider);
    final controller = ref.read(chatOptionsControllerProvider.notifier);
    final server = _server;
    final selectedModel = options.model.toLowerCase();

    return Scaffold(
      appBar: AppBar(title: const Text('对话设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section(
            '模型',
            [
              if (server == null)
                const Text(
                  '未能读取服务端模型清单（服务端不可达）。',
                  style: TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
                )
              else if (server.candidates.isEmpty)
                const Text(
                  '未能获取可用模型清单：请确认后端已启用 AI 且本机 Ollama 可访问（后端页面可一键拉起）。',
                  style: TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
                )
              else
                for (final candidate in server.candidates)
                  _ModelOption(
                    model: candidate.model,
                    installed: candidate.installed,
                    vision: candidate.vision,
                    // 未显式选过模型（model 为空）时以服务端当前选定的模型为准
                    selected: selectedModel.isEmpty
                        ? candidate.current
                        : selectedModel == candidate.model.toLowerCase(),
                    active: server.activeModel.toLowerCase() ==
                        candidate.model.toLowerCase(),
                    // 未安装的模型不允许选中：选中后每次对话都会失败
                    onTap: candidate.installed
                        ? () => controller.update(
                              options.copyWith(model: candidate.model),
                            )
                        : null,
                  ),
              const SizedBox(height: 4),
              const Text(
                '候选实时来自本机 Ollama 的已安装模型（在后端 ollama pull / rm 后刷新即可）。'
                '两端选用不同模型时，对话会抢占后台标注并释放显存（原任务会被中断，之后自动重排）。',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          _section(
            '上下文大小',
            [
              Wrap(
                spacing: 8,
                children: [
                  for (final choice in ChatOptions.ctxChoices)
                    ChoiceChip(
                      label: Text(choice == 0 ? '默认' : '${choice ~/ 1024}K'),
                      selected: options.numCtx == choice,
                      onSelected: (_) =>
                          controller.update(options.copyWith(numCtx: choice)),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                options.numCtx == 0
                    ? '跟随后端默认${server != null ? '（${server.numCtx}）' : ''}；'
                        '改动窗口会让模型重新加载，按需调整即可。'
                    : '当前 ${options.numCtx} token；改动窗口会让模型重新加载。',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          _section(
            '思考深度',
            [
              const Text(
                '「近期回顾」是一次性写作，固定不使用思考链；本开关只影响对话。',
                style: TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
              ),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('深度思考', style: TextStyle(fontSize: 14)),
                subtitle: const Text(
                  '开启后模型先输出思考过程再作答，更慢但更稳；关闭则直接回答。',
                  style: TextStyle(fontSize: 12),
                ),
                value: options.think,
                onChanged: (value) =>
                    controller.update(options.copyWith(think: value)),
              ),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('采样温度', style: TextStyle(fontSize: 14)),
                subtitle: Slider(
                  value: options.temperature.clamp(0, 2),
                  max: 2,
                  divisions: 20,
                  label: options.temperature.toStringAsFixed(1),
                  onChanged: (value) => controller.update(
                    options.copyWith(
                      temperature: (value * 10).roundToDouble() / 10,
                    ),
                  ),
                ),
                trailing: Text(options.temperature.toStringAsFixed(1)),
              ),
            ],
          ),
          _section(
            '模型卸载超时',
            [
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('自定义卸载时间', style: TextStyle(fontSize: 14)),
                subtitle: Text(
                  options.customKeepAlive
                      ? '停止对话 ${options.keepAliveSeconds} 秒后卸载模型'
                      : '使用后端默认${server != null ? '（${server.keepAliveSeconds} 秒）' : ''}',
                  style: const TextStyle(fontSize: 12),
                ),
                value: options.customKeepAlive,
                onChanged: (value) {
                  if (!value) {
                    controller.update(options.copyWith(customKeepAlive: false));
                    return;
                  }
                  final seconds = int.tryParse(_keepAliveController.text.trim());
                  controller.update(
                    options.copyWith(
                      customKeepAlive: true,
                      keepAliveSeconds: _validKeepAlive(seconds),
                    ),
                  );
                },
              ),
              if (options.customKeepAlive)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: TextField(
                    controller: _keepAliveController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '卸载等待秒数',
                      helperText: '0 = 回答完立即卸载；数值越大模型驻留越久（显存占用更久）',
                      helperMaxLines: 2,
                      suffixText: '秒',
                      isDense: true,
                    ),
                    onSubmitted: (raw) => _applyKeepAlive(options, raw),
                    onEditingComplete: () =>
                        _applyKeepAlive(options, _keepAliveController.text),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _applyKeepAlive(ChatOptions options, String raw) {
    final seconds = _validKeepAlive(int.tryParse(raw.trim()));
    _keepAliveController.text = seconds.toString();
    ref.read(chatOptionsControllerProvider.notifier).update(
          options.copyWith(customKeepAlive: true, keepAliveSeconds: seconds),
        );
  }

  /// 合法区间与后端一致（1 秒 ~ 24 小时），越界回落到默认 300 秒；0 允许（立即卸载）。
  int _validKeepAlive(int? seconds) {
    if (seconds == null || seconds < 0 || seconds > 86400) return 300;
    return seconds;
  }

  Widget _section(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 6),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// 单个模型选项：模型名 + 已安装/运行中/无视觉标识。
class _ModelOption extends StatelessWidget {
  const _ModelOption({
    required this.model,
    required this.installed,
    required this.vision,
    required this.selected,
    required this.active,
    required this.onTap,
  });

  final String model;
  final bool installed;
  final bool vision;
  final bool selected;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      enabled: onTap != null,
      onTap: onTap,
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        size: 20,
        color: selected ? AppTheme.primary : AppTheme.onSurfaceVariant,
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              model,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          if (active) ...[
            const SizedBox(width: 6),
            const Text(
              '运行中',
              style: TextStyle(fontSize: 11, color: AppTheme.secondary),
            ),
          ],
          if (!installed) ...[
            const SizedBox(width: 6),
            const Text(
              '未安装',
              style: TextStyle(fontSize: 11, color: AppTheme.errorVivid),
            ),
          ] else if (!vision) ...[
            const SizedBox(width: 6),
            const Text(
              '无视觉',
              style: TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}
