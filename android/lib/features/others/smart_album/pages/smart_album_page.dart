import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/chat/chat_entry.dart';
import 'package:torrid/features/others/ai/models/ai_search_models.dart';
import 'package:torrid/features/others/ai/services/ai_api_service.dart';
import 'package:torrid/features/others/smart_album/providers/smart_album_providers.dart';
import 'package:torrid/features/others/widgets/media_viewer_page.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';

/// 智能相册页：文本搜图 / 以图搜图 / 人物分组 / AI 分析结果查看。
///
/// 与画廊页同为一级入口（见 `pages_data.dart`）。
/// 只消费服务端 AI 能力：结果按需拉取，不写入本地缓存，也不改动画廊的下载与标注链路；
/// 页面内不出现人工标签——人工标签归相册(immich)页。
/// 本页只做渲染与导航，检索状态与编排在 `smart_album_providers.dart`。
class SmartAlbumPage extends ConsumerStatefulWidget {
  const SmartAlbumPage({super.key});

  @override
  ConsumerState<SmartAlbumPage> createState() => _SmartAlbumPageState();
}

class _SmartAlbumPageState extends ConsumerState<SmartAlbumPage>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();

  /// 检索 / 人物两个视图；由本 State 持有，避免在 State 里读
  /// DefaultTabController.of(context)（那个 context 在控制器之上，会抛错）。
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() {
      if (_tabs.indexIsChanging) return;
      final state = ref.read(smartAlbumControllerProvider);
      if (_tabs.index == 1 && state.persons == null && !state.loading) {
        ref.read(smartAlbumControllerProvider.notifier).loadPersons();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(smartAlbumControllerProvider);
    final controller = ref.read(smartAlbumControllerProvider.notifier);

    // 控制器要求回填输入框时（以图搜图 / 点人物）同步一次
    ref.listen(
      smartAlbumControllerProvider.select((value) => value.queryRevision),
      (previous, next) {
        if (previous == next) return;
        _controller.text =
            ref.read(smartAlbumControllerProvider).queryText;
      },
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('智能相册'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: '检索'),
            Tab(text: '人物'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildSearchView(state, controller),
          _buildPersonsView(state, controller),
        ],
      ),
    );
  }

  // ---------- 检索 ----------

  Widget _buildSearchView(
    SmartAlbumState state,
    SmartAlbumController controller,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: TextField(
            controller: _controller,
            style: const TextStyle(color: Colors.white),
            textInputAction: TextInputAction.search,
            onSubmitted: controller.search,
            decoration: InputDecoration(
              hintText: state.mode == AiSearchMode.filename
                  ? '文件名或扩展名，如：IMG_2024 / .mp4'
                  : '描述想要的画面，如：可爱的猫娘 / 夜景街道',
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              suffixIcon: IconButton(
                icon: const Icon(Icons.close, color: Colors.grey, size: 18),
                onPressed: () {
                  _controller.clear();
                  controller.clearResult();
                },
              ),
              filled: true,
              fillColor: const Color(0xFF1C1C1C),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final mode in AiSearchMode.values) ...[
                        ChoiceChip(
                          label: Text(mode.label),
                          selected: state.mode == mode,
                          onSelected: (_) {
                            controller.setMode(mode);
                            // 切换检索方式后旧结果不再对应，有查询词就重搜一次
                            if (_controller.text.trim().isNotEmpty) {
                              controller.search(_controller.text);
                            }
                          },
                          // 深色页面下必须显式给配色：主题是浅色，未选中 chip 的
                          // 默认底色与白字撞在一起会看不见文字
                          backgroundColor: const Color(0xFF1C1C1C),
                          selectedColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                          showCheckmark: false,
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          labelStyle: TextStyle(
                            color: state.mode == mode ? Colors.black : Colors.white,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: state.loading
                    ? null
                    : () => controller.search(_controller.text),
                icon: const Icon(Icons.search, size: 16),
                label: const Text('搜索'),
                style: TextButton.styleFrom(foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
        if (state.loading) const LinearProgressIndicator(minHeight: 2),
        if (state.error != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              state.error!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ),
        Expanded(child: _buildResultGrid(state, controller)),
      ],
    );
  }

  Widget _buildResultGrid(
    SmartAlbumState state,
    SmartAlbumController controller,
  ) {
    final result = state.result;
    if (result.hits.isEmpty) {
      return Center(
        child: Text(
          state.loading ? '检索中…' : '输入关键词开始检索',
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    final api = ref.watch(apiClientManagerProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '命中 ${result.total} 条 · ${_modeLabel(result.mode)}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(4),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 3,
              crossAxisSpacing: 3,
            ),
            itemCount: result.hits.length,
            itemBuilder: (context, index) {
              final hit = result.hits[index];
              return _HitTile(
                hit: hit,
                url: hit.thumbUrl(api.baseUrl),
                headers: api.headers,
                onTap: () => _openViewer(result, index, controller),
              );
            },
          ),
        ),
      ],
    );
  }

  /// 打开全屏查看器：本页只注入"以图搜图"和"AI 分析"两个智能操作。
  void _openViewer(
    AiSearchResult result,
    int index,
    SmartAlbumController controller,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MediaViewerPage(
          assets: [for (final hit in result.hits) hit.toAsset()],
          initialIndex: index,
          subtitleBuilder: (asset) {
            final hit = _hitById(result, asset.id);
            if (hit == null || hit.score <= 0) return null;
            return '相关度 ${hit.score.toStringAsFixed(3)}';
          },
          actions: (context, asset) => [
            IconButton(
              icon: const Icon(Icons.auto_awesome),
              tooltip: '问问AI',
              onPressed: () => askAiAboutMedia(
                context,
                mediaId: asset.id,
                fileName: asset.filePath.split(RegExp(r'[/\\]')).last,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.image_search),
              tooltip: '以图搜图',
              onPressed: () {
                Navigator.of(context).pop();
                unawaited(controller.searchSimilar(asset.id));
              },
            ),
            IconButton(
              icon: const Icon(Icons.description_outlined),
              tooltip: 'AI 分析',
              onPressed: () => _showAiDetail(asset.id),
            ),
          ],
        ),
      ),
    );
  }

  AiSearchHit? _hitById(AiSearchResult result, String id) {
    for (final hit in result.hits) {
      if (hit.id == id) return hit;
    }
    return null;
  }

  // ---------- 人物 ----------

  Widget _buildPersonsView(
    SmartAlbumState state,
    SmartAlbumController controller,
  ) {
    final persons = state.persons;
    if (persons == null) {
      return Center(
        child: state.loading
            ? const CircularProgressIndicator(color: Colors.white70)
            : FilledButton(
                onPressed: controller.loadPersons,
                child: const Text('加载人物分组'),
              ),
      );
    }
    if (persons.isEmpty) {
      return const Center(
        child: Text('暂无人物分组', style: TextStyle(color: Colors.grey)),
      );
    }

    final api = ref.watch(apiClientManagerProvider);

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '点击人物即在「检索」中查看其全部照片',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.78,
            ),
            itemCount: persons.length,
            itemBuilder: (context, index) {
              final person = persons[index];
              return InkWell(
                // 先切页再请求：用户点了就必须有反馈，不能只等结果
                onTap: () {
                  _tabs.animateTo(0);
                  controller.searchByPerson(person);
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: person.coverMediaId == null
                            ? const ColoredBox(
                                color: Color(0xFF2B2B2B),
                                child: Icon(Icons.person_outline,
                                    color: Colors.grey),
                              )
                            : CachedNetworkImage(
                                imageUrl:
                                    '${api.baseUrl}/API/gallery/${person.coverMediaId}/thumb',
                                httpHeaders: api.headers,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => const ColoredBox(
                                  color: Color(0xFF2B2B2B),
                                  child: Icon(Icons.broken_image_outlined,
                                      color: Colors.grey),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      person.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    Text(
                      '${person.faceCount} 张',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ---------- 动作 ----------

  /// 只读展示该媒体的 AI 分析结果（描述 / 关键词 / OCR）。
  Future<void> _showAiDetail(String mediaId) async {
    AiMediaDetail? detail;
    String? error;
    try {
      detail = await ref.read(aiApiProvider).fetchMediaDetail(mediaId);
    } catch (e) {
      error = e.toString();
    }
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1C1C1C),
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.64,
            minWidth: MediaQuery.sizeOf(sheetContext).width,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: error != null
                ? Text(
                    '读取 AI 结果失败: $error',
                    style: const TextStyle(
                        color: Colors.redAccent, fontSize: 13),
                  )
                : _buildAiDetailBody(detail!),
          ),
        ),
      ),
    );
  }

  Widget _buildAiDetailBody(AiMediaDetail detail) {
    const titleStyle =
        TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600);
    const bodyStyle = TextStyle(color: Colors.white70, fontSize: 13);
    const emptyStyle = TextStyle(color: Colors.grey, fontSize: 12);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('AI 分析', style: titleStyle),
        const SizedBox(height: 12),
        const Text('画面描述', style: titleStyle),
        const SizedBox(height: 4),
        Text(detail.caption ?? '暂无（尚未做 VLM 处理）',
            style: detail.caption == null ? emptyStyle : bodyStyle),
        const SizedBox(height: 14),
        const Text('AI 关键词', style: titleStyle),
        const SizedBox(height: 6),
        if (detail.vlmTags.isEmpty)
          const Text('暂无', style: emptyStyle)
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tag in detail.vlmTags)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2B2B2B),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(tag,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12)),
                ),
            ],
          ),
        const SizedBox(height: 14),
        const Text('识别文字', style: titleStyle),
        const SizedBox(height: 4),
        Text(detail.ocrText ?? '暂无', style: detail.ocrText == null ? emptyStyle : bodyStyle),
      ],
    );
  }

  String _modeLabel(String mode) {
    for (final item in AiSearchMode.values) {
      if (item.value == mode) return '${item.label}检索';
    }
    return mode;
  }
}

/// 单个命中缩略图。
class _HitTile extends StatelessWidget {
  final AiSearchHit hit;
  final String url;
  final Map<String, String> headers;
  final VoidCallback onTap;

  const _HitTile({
    required this.hit,
    required this.url,
    required this.headers,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: url,
            httpHeaders: headers,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => const ColoredBox(
              color: Color(0xFF2B2B2B),
              child: Icon(Icons.broken_image_outlined, color: Colors.grey),
            ),
          ),
          if (hit.isVideo)
            const Positioned(
              right: 4,
              bottom: 4,
              child: Icon(Icons.play_circle_fill,
                  color: Colors.white70, size: 16),
            ),
        ],
      ),
    );
  }
}
