import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/others/ai/models/ai_search_models.dart';
import 'package:torrid/features/others/ai/services/ai_api_service.dart';
import 'package:torrid/features/others/widgets/media_viewer_page.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';

/// 智能相册页：文本搜图 / 以图搜图 / 人物分组 / AI 分析结果查看。
///
/// 与画廊页同为一级入口（见 `pages_data.dart`），不再依赖画廊网格页跳转。
/// 只消费服务端 AI 能力：结果按需拉取，不写入本地缓存，也不改动画廊的下载与标注链路；
/// 页面内不出现人工标签——人工标签归相册(immich)页。
class SmartAlbumPage extends ConsumerStatefulWidget {
  const SmartAlbumPage({super.key});

  @override
  ConsumerState<SmartAlbumPage> createState() => _SmartAlbumPageState();
}

class _SmartAlbumPageState extends ConsumerState<SmartAlbumPage> {
  final _controller = TextEditingController();

  /// 默认使用智能检索。
  AiSearchMode _mode = AiSearchMode.auto;
  bool _loading = false;
  String? _error;
  AiSearchResult _result = AiSearchResult.empty;

  /// 人物视图的数据（懒加载，切换时才请求）。
  List<AiPerson>? _persons;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: const Text('智能相册'),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: '检索'),
              Tab(text: '人物'),
            ],
          ),
        ),
        body: TabBarView(
          children: [_buildSearchView(), _buildPersonsView()],
        ),
      ),
    );
  }

  // ---------- 检索 ----------

  Widget _buildSearchView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: TextField(
            controller: _controller,
            style: const TextStyle(color: Colors.white),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              hintText: _mode == AiSearchMode.filename
                  ? '文件名或扩展名，如：IMG_2024 / .mp4'
                  : '描述想要的画面，如：可爱的猫娘 / 夜景街道',
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              suffixIcon: IconButton(
                icon: const Icon(Icons.close, color: Colors.grey, size: 18),
                onPressed: () {
                  _controller.clear();
                  setState(() => _result = AiSearchResult.empty);
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
                          selected: _mode == mode,
                          onSelected: (_) {
                            setState(() => _mode = mode);
                            // 切换检索方式后旧结果不再对应，清掉避免误读
                            _result = AiSearchResult.empty;
                            if (_controller.text.trim().isNotEmpty) _search();
                          },
                          labelStyle: TextStyle(
                            color: _mode == mode ? Colors.black : Colors.white,
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
                onPressed: _loading ? null : _search,
                icon: const Icon(Icons.search, size: 16),
                label: const Text('搜索'),
              ),
            ],
          ),
        ),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ),
        Expanded(child: _buildResultGrid()),
      ],
    );
  }

  Widget _buildResultGrid() {
    if (_result.hits.isEmpty) {
      return Center(
        child: Text(
          _loading ? '检索中…' : '输入关键词开始检索',
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
              '命中 ${_result.total} 条 · ${_modeLabel(_result.mode)}',
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
            itemCount: _result.hits.length,
            itemBuilder: (context, index) {
              final hit = _result.hits[index];
              return _HitTile(
                hit: hit,
                url: hit.thumbUrl(api.baseUrl),
                headers: api.headers,
                onTap: () => _openViewer(index),
              );
            },
          ),
        ),
      ],
    );
  }

  /// 打开全屏查看器：本页只注入"以图搜图"和"AI 分析"两个智能操作。
  void _openViewer(int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MediaViewerPage(
          assets: [for (final hit in _result.hits) hit.toAsset()],
          initialIndex: index,
          subtitleBuilder: (asset) {
            final hit = _hitById(asset.id);
            if (hit == null || hit.score <= 0) return null;
            return '相关度 ${hit.score.toStringAsFixed(3)}';
          },
          actions: (context, asset) => [
            IconButton(
              icon: const Icon(Icons.image_search),
              tooltip: '以图搜图',
              onPressed: () {
                Navigator.of(context).pop();
                unawaited(_searchSimilar(asset.id));
              },
            ),
            IconButton(
              icon: const Icon(Icons.auto_awesome),
              tooltip: 'AI 分析',
              onPressed: () => _showAiDetail(asset.id),
            ),
          ],
        ),
      ),
    );
  }

  AiSearchHit? _hitById(String id) {
    for (final hit in _result.hits) {
      if (hit.id == id) return hit;
    }
    return null;
  }

  // ---------- 人物 ----------

  Widget _buildPersonsView() {
    if (_persons == null) {
      return Center(
        child: _loading
            ? const CircularProgressIndicator()
            : FilledButton(
                onPressed: _loadPersons,
                child: const Text('加载人物分组'),
              ),
      );
    }
    if (_persons!.isEmpty) {
      return const Center(
        child: Text('暂无人物分组', style: TextStyle(color: Colors.grey)),
      );
    }

    final api = ref.watch(apiClientManagerProvider);

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.78,
      ),
      itemCount: _persons!.length,
      itemBuilder: (context, index) {
        final person = _persons![index];
        return InkWell(
          onTap: () => _searchByPerson(person),
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
    );
  }

  // ---------- 动作 ----------

  Future<void> _search() async {
    final query = _controller.text.trim();
    // 纯条件检索（文件名模式必须给词）没有查询词时不做请求
    if (query.isEmpty && _mode == AiSearchMode.filename) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref.read(aiApiProvider).search(query, mode: _mode);
      if (!mounted) return;
      setState(() => _result = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _searchSimilar(String mediaId) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref.read(aiApiProvider).similar(mediaId);
      if (!mounted) return;
      setState(() {
        _result = result;
        _controller.text = '与所选图片相似';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadPersons() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final persons = await ref.read(aiApiProvider).fetchPersons();
      if (!mounted) return;
      setState(() => _persons = persons);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _searchByPerson(AiPerson person) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref.read(aiApiProvider).searchByPerson(person.id);
      if (!mounted) return;
      setState(() {
        _result = result;
        _controller.text = person.displayName;
      });
      DefaultTabController.of(context).animateTo(0);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

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
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.6,
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
