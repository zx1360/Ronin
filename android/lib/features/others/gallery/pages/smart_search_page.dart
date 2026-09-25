import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/others/gallery/models/ai_search_models.dart';
import 'package:torrid/features/others/gallery/services/ai_api_service.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';

/// 智能相册页：文本搜图 / 以图搜图 / 人物分组。
///
/// 这是 Android 端消费服务端 AI 能力的最小入口：结果直接按需拉取，
/// 不写入本地缓存，也不改动现有画廊的下载与标注链路。
class SmartSearchPage extends ConsumerStatefulWidget {
  const SmartSearchPage({super.key});

  @override
  ConsumerState<SmartSearchPage> createState() => _SmartSearchPageState();
}

class _SmartSearchPageState extends ConsumerState<SmartSearchPage> {
  final _controller = TextEditingController();

  /// semantic=语义检索（SigLIP），keyword=OCR/描述/标签关键词。
  bool _semantic = true;
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
              hintText: '描述想要的画面，如：可爱的猫娘 / 夜景街道',
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
              ChoiceChip(
                label: const Text('语义'),
                selected: _semantic,
                onSelected: (_) => setState(() => _semantic = true),
                labelStyle: TextStyle(
                  color: _semantic ? Colors.black : Colors.white,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('文字'),
                selected: !_semantic,
                onSelected: (_) => setState(() => _semantic = false),
                labelStyle: TextStyle(
                  color: _semantic ? Colors.white : Colors.black,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
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

    final baseUrl = ref.read(apiClientManagerProvider).baseUrl;
    final headers = ref.read(apiClientManagerProvider).headers;

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
                url: hit.thumbUrl(baseUrl),
                headers: headers,
                onTap: () => _showActions(hit),
              );
            },
          ),
        ),
      ],
    );
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

    final baseUrl = ref.read(apiClientManagerProvider).baseUrl;
    final headers = ref.read(apiClientManagerProvider).headers;

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
                              '$baseUrl/API/gallery/${person.coverMediaId}/thumb',
                          httpHeaders: headers,
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
    if (query.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref.read(aiApiProvider).search(
            query,
            mode: _semantic ? 'auto' : 'keyword',
          );
      if (!mounted) return;
      setState(() => _result = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _searchSimilar(AiSearchHit hit) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref.read(aiApiProvider).similar(hit.id);
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

  /// 命中结果的可用操作（当前只有以图搜图，保持入口最小）。
  Future<void> _showActions(AiSearchHit hit) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1C1C1C),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                hit.fileName,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.image_search, color: Colors.white),
              title: const Text('以图搜图',
                  style: TextStyle(color: Colors.white, fontSize: 14)),
              onTap: () {
                Navigator.of(sheetContext).pop();
                unawaited(_searchSimilar(hit));
              },
            ),
            if (hit.score > 0)
              ListTile(
                leading: const Icon(Icons.insights, color: Colors.grey),
                title: Text(
                  '相关度 ${hit.score.toStringAsFixed(3)}'
                  '${hit.source.isEmpty ? '' : ' · ${hit.source.join('/')}'}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _modeLabel(String mode) {
    switch (mode) {
      case 'semantic':
        return '语义检索';
      case 'keyword':
        return '文字检索';
      default:
        return mode;
    }
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
