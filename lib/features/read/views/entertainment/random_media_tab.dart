import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:torrid/core/modals/snack_bar.dart';
import 'package:torrid/core/services/io/io_service.dart';
import 'package:torrid/core/utils/file_relates.dart';
import 'package:torrid/core/utils/util.dart';
import 'package:torrid/features/read/providers/sixty_api_provider.dart';
import 'package:torrid/features/read/widgets/common.dart';
import 'package:torrid/features/read/widgets/image_preview.dart';
import 'package:torrid/core/constants/spacing.dart';
import 'package:url_launcher/url_launcher.dart';

enum RandomMediaApi { aa1Sjtp2, aa1Sjtp1, aa1Whr1, aa1X7bb, okcodeXjjVideo }

enum OkcodeReturnType { json, video }

enum X7bbPreset { mn, dm, custom }

enum MediaKind { image, video }

enum MediaKindMode { auto, image, video }

class RandomMediaTab extends ConsumerStatefulWidget {
  const RandomMediaTab({super.key});

  @override
  ConsumerState<RandomMediaTab> createState() => _RandomMediaTabState();
}

class _RandomMediaTabState extends ConsumerState<RandomMediaTab> {
  RandomMediaApi _api = RandomMediaApi.aa1X7bb;

  // x7bb
  X7bbPreset _x7bbPreset = X7bbPreset.mn;
  final TextEditingController _x7bbCustomTController = TextEditingController();
  MediaKindMode _x7bbKindMode = MediaKindMode.auto;

  // okcode
  final TextEditingController _okcodeKeyController = TextEditingController();
  OkcodeReturnType _okcodeType = OkcodeReturnType.json;

  // result
  int _nonce = 0;
  bool _loading = false;
  String? _error;
  String? _mediaUrl;
  MediaKind? _mediaKind;

  @override
  void initState() {
    super.initState();
    setState(() {
      _okcodeKeyController.text = 'gngCBLoc7bInwotibiqFCCg0';
    });
  }

  @override
  void dispose() {
    _x7bbCustomTController.dispose();
    _okcodeKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          const SectionTitle(title: '随机图片/视频', icon: Icons.shuffle),
          const SizedBox(height: AppSpacing.sm),
          _buildControls(context),
          const SizedBox(height: AppSpacing.md),
          _buildResult(context),
        ],
      ),
    );
  }

  Widget _buildControls(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<RandomMediaApi>(
          key: ValueKey(_api),
          initialValue: _api,
          decoration: const InputDecoration(
            labelText: 'API 选择',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(
              value: RandomMediaApi.aa1X7bb,
              child: Text('AA1 / x7bb 随机图片/视频 (t 必填)'),
            ),
            DropdownMenuItem(
              value: RandomMediaApi.okcodeXjjVideo,
              child: Text('OkCode 小姐姐视频 (key/type 必填)'),
            ),
            DropdownMenuItem(
              value: RandomMediaApi.aa1Sjtp2,
              child: Text('AA1 随机图片显示版 (直出图片)'),
            ),
            DropdownMenuItem(
              value: RandomMediaApi.aa1Sjtp1,
              child: Text('AA1 随机图片下载版 (可能重定向)'),
            ),
            DropdownMenuItem(
              value: RandomMediaApi.aa1Whr1,
              child: Text('AA1 随机图片 2.0 (直出图片/重定向)'),
            ),
          ],
          onChanged: (v) {
            if (v == null) return;
            setState(() {
              _api = v;
              _error = null;
              _mediaUrl = null;
              _mediaKind = null;
            });
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        ...switch (_api) {
          RandomMediaApi.aa1X7bb => [_buildX7bbControls(context)],
          RandomMediaApi.okcodeXjjVideo => [_buildOkcodeControls(context)],
          _ => [
            Text(
              '该接口无参数。点击“刷新”获取新的图片地址（会自动加时间戳避免缓存）。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        },
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            FilledButton.icon(
              onPressed: _loading ? null : _refresh,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              label: const Text('刷新'),
            ),
            const SizedBox(width: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: (_mediaUrl == null || _loading)
                  ? null
                  : () => _downloadMedia(
                      context,
                      ref,
                      _mediaUrl!,
                      _suggestBaseName(),
                      _mediaKind ?? MediaKind.image,
                    ),
              icon: const Icon(Icons.download),
              label: const Text('下载到本地'),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          ErrorView(_error!),
        ],
      ],
    );
  }

  Widget _buildX7bbControls(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<X7bbPreset>(
                key: ValueKey(_x7bbPreset),
                initialValue: _x7bbPreset,
                decoration: const InputDecoration(
                  labelText: '参数 t（必填）',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: X7bbPreset.mn,
                    child: Text('mn（美女图片）'),
                  ),
                  DropdownMenuItem(
                    value: X7bbPreset.dm,
                    child: Text('dm（动漫图片）'),
                  ),
                  DropdownMenuItem(
                    value: X7bbPreset.custom,
                    child: Text('自定义'),
                  ),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _x7bbPreset = v;
                    _error = null;
                    _mediaUrl = null;
                    _mediaKind = null;
                  });
                },
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            SizedBox(
              width: 160,
              child: DropdownButtonFormField<MediaKindMode>(
                key: ValueKey(_x7bbKindMode),
                initialValue: _x7bbKindMode,
                decoration: const InputDecoration(
                  labelText: '媒体类型',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: MediaKindMode.auto,
                    child: Text('自动'),
                  ),
                  DropdownMenuItem(
                    value: MediaKindMode.image,
                    child: Text('图片'),
                  ),
                  DropdownMenuItem(
                    value: MediaKindMode.video,
                    child: Text('视频'),
                  ),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _x7bbKindMode = v;
                    _error = null;
                    _mediaUrl = null;
                    _mediaKind = null;
                  });
                },
              ),
            ),
          ],
        ),
        if (_x7bbPreset == X7bbPreset.custom) ...[
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _x7bbCustomTController,
            decoration: const InputDecoration(
              labelText: '自定义 t（必填）',
              hintText: '例如：mn / dm ...（按文档填写）',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) {
              setState(() {
                _error = null;
                _mediaUrl = null;
                _mediaKind = null;
              });
            },
          ),
        ],
      ],
    );
  }

  Widget _buildOkcodeControls(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _okcodeKeyController,
          decoration: const InputDecoration(
            labelText: 'key（必填）',
            hintText: 'OkCode 控制台获取的接口密钥',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) {
            setState(() {
              _error = null;
              _mediaUrl = null;
              _mediaKind = null;
            });
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<OkcodeReturnType>(
          key: ValueKey(_okcodeType),
          initialValue: _okcodeType,
          decoration: const InputDecoration(
            labelText: 'type（必填）',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(
              value: OkcodeReturnType.json,
              child: Text('json（返回 video_url）'),
            ),
            DropdownMenuItem(
              value: OkcodeReturnType.video,
              child: Text('video（直接返回视频数据）'),
            ),
          ],
          onChanged: (v) {
            if (v == null) return;
            setState(() {
              _okcodeType = v;
              _error = null;
              _mediaUrl = null;
              _mediaKind = null;
            });
          },
        ),
      ],
    );
  }

  Widget _buildResult(BuildContext context) {
    if (_mediaUrl == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Center(child: Text('点击“刷新”开始获取随机内容。')),
      );
    }

    final url = _mediaUrl!;
    final kind = _mediaKind ?? MediaKind.image;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(url, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: AppSpacing.sm),
        if (kind == MediaKind.image)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: GestureDetector(
              onTap: () => showImagePreview(context, url),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  url,
                  key: ValueKey(url),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, _) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Text('图片加载失败：$error'),
                      ),
                    );
                  },
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(child: CircularProgressIndicator());
                  },
                ),
              ),
            ),
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  const Icon(Icons.play_circle_outline),
                  const SizedBox(width: AppSpacing.sm),
                  const Expanded(child: Text('视频无法在此处内嵌播放，点击右侧打开。')),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton.icon(
                    onPressed: () => _openUrl(context, url),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('打开'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
      _mediaUrl = null;
      _mediaKind = null;
      _nonce += 1;
    });

    try {
      final result = await _resolveMedia();
      if (mounted) {
        setState(() {
          _mediaUrl = result.url;
          _mediaKind = result.kind;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '获取失败：$e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<_ResolvedMedia> _resolveMedia() async {
    final nonce = _nonce;

    switch (_api) {
      case RandomMediaApi.aa1Sjtp2:
        return _ResolvedMedia(
          url: _withNonce('https://api.luochen.sbs/API/sjtp2.php', nonce),
          kind: MediaKind.image,
        );
      case RandomMediaApi.aa1Sjtp1:
        return _ResolvedMedia(
          url: _withNonce('https://api.luochen.sbs/API/sjtp1.php', nonce),
          kind: MediaKind.image,
        );
      case RandomMediaApi.aa1Whr1:
        return _ResolvedMedia(
          url: _withNonce('http://api.xunjinlu.fun/api/img2/index.php', nonce),
          kind: MediaKind.image,
        );
      case RandomMediaApi.aa1X7bb:
        final t = _resolveX7bbT();
        if (t.isEmpty) {
          throw Exception('参数 t 为必填');
        }
        final url = _withNonce('https://x7bb.cn/7/api/?t=$t', nonce);
        final kind = await _resolveKindForX7bb(url);
        return _ResolvedMedia(url: url, kind: kind);
      case RandomMediaApi.okcodeXjjVideo:
        final key = _okcodeKeyController.text.trim();
        if (key.isEmpty) {
          throw Exception('参数 key 为必填');
        }
        final type = _okcodeType == OkcodeReturnType.json ? 'json' : 'video';
        final endpoint = 'https://api.okcode.vip/api/video/xjj';

        if (_okcodeType == OkcodeReturnType.json) {
          final client = ref.read(sixtyApiClientProvider);
          final resp = await client.get(
            endpoint,
            queryParams: {'key': key, 'type': type},
          );

          final data = resp.data;
          if (data is! Map) {
            throw Exception('返回格式异常：$data');
          }
          final code = data['code'];
          if (code != 200) {
            throw Exception('接口返回 code=$code：${data['msg']}');
          }
          final inner = data['data'];
          if (inner is! Map) {
            throw Exception('返回 data 异常：$inner');
          }
          final videoUrl = inner['video_url'];
          if (videoUrl is! String || videoUrl.trim().isEmpty) {
            throw Exception('video_url 为空');
          }
          return _ResolvedMedia(
            url: _withNonce(videoUrl.trim(), nonce),
            kind: MediaKind.video,
          );
        }

        // type=video：接口会直接返回视频数据；为了“查看/打开”，这里直接使用请求 URL。
        final requestUrl = _withNonce(
          '$endpoint?key=${Uri.encodeQueryComponent(key)}&type=$type',
          nonce,
        );
        return _ResolvedMedia(url: requestUrl, kind: MediaKind.video);
    }
  }

  String _resolveX7bbT() {
    switch (_x7bbPreset) {
      case X7bbPreset.mn:
        return 'mn';
      case X7bbPreset.dm:
        return 'dm';
      case X7bbPreset.custom:
        return _x7bbCustomTController.text.trim();
    }
  }

  Future<MediaKind> _resolveKindForX7bb(String url) async {
    switch (_x7bbKindMode) {
      case MediaKindMode.image:
        return MediaKind.image;
      case MediaKindMode.video:
        return MediaKind.video;
      case MediaKindMode.auto:
        // 预置类型可直接判断
        if (_x7bbPreset == X7bbPreset.mn || _x7bbPreset == X7bbPreset.dm) {
          return MediaKind.image;
        }

        // 尝试用 HEAD 的 content-type 做一次轻量识别（支持重定向）
        try {
          final dio = Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 6),
              receiveTimeout: const Duration(seconds: 6),
              followRedirects: true,
            ),
          );
          final resp = await dio.head(
            url,
            options: Options(
              validateStatus: (s) => s != null && s >= 200 && s < 500,
            ),
          );
          final contentType = resp.headers.value('content-type') ?? '';
          if (contentType.contains('video/')) return MediaKind.video;
          if (contentType.contains('image/')) return MediaKind.image;
        } catch (_) {
          // ignore
        }

        // 兜底：根据 url 扩展名
        final ext = getFileExtension(Uri.parse(url).path);
        if (ext == 'mp4' || ext == 'mov' || ext == 'mkv' || ext == 'webm') {
          return MediaKind.video;
        }
        return MediaKind.image;
    }
  }

  String _withNonce(String rawUrl, int nonce) {
    final uri = Uri.parse(rawUrl);
    final qp = Map<String, dynamic>.from(uri.queryParameters);
    qp['_ts'] = DateTime.now().millisecondsSinceEpoch.toString();
    qp['_n'] = nonce.toString();
    return uri.replace(queryParameters: qp).toString();
  }

  String _suggestBaseName() {
    final apiName = switch (_api) {
      RandomMediaApi.aa1Sjtp2 => 'aa1_sjtp2',
      RandomMediaApi.aa1Sjtp1 => 'aa1_sjtp1',
      RandomMediaApi.aa1Whr1 => 'aa1_whr1',
      RandomMediaApi.aa1X7bb => 'x7bb_${_resolveX7bbT()}',
      RandomMediaApi.okcodeXjjVideo => 'okcode_xjj',
    };
    return apiName;
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      displaySnackBar(context, 'URL 无效');
      return;
    }

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      displaySnackBar(context, '无法打开链接');
    }
  }
}

class _ResolvedMedia {
  final String url;
  final MediaKind kind;

  const _ResolvedMedia({required this.url, required this.kind});
}

Future<void> _downloadMedia(
  BuildContext context,
  WidgetRef ref,
  String url,
  String fileBaseName,
  MediaKind kind,
) async {
  try {
    final client = ref.read(sixtyApiClientProvider);
    final resp = await client.getBinary(url);
    final bytes = resp.data;
    if (bytes == null || bytes.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('下载失败：无数据')));
      }
      return;
    }

    final dir = await IoService.externalStorageDir;
    await IoService.ensureDirExists('api_medias');

    final uri = Uri.tryParse(url);
    final extFromUrl = uri == null ? '' : getFileExtension(uri.path);
    final ext = (extFromUrl.isNotEmpty)
        ? extFromUrl
        : (kind == MediaKind.video ? 'mp4' : 'jpg');

    final safeBase = sanitizeDirectoryName(fileBaseName.replaceAll(' ', '_'));
    final fileName =
        '${safeBase}_${getTodayDateString()}_${generateFileName()}.$ext';
    final file = File(p.join(dir.path, 'api_medias', fileName));

    if (await file.exists()) {
      await file.delete();
    }

    await file.writeAsBytes(bytes);
    if (!context.mounted) return;
    displaySnackBar(context, '已保存到：${file.path}');
  } catch (e) {
    if (!context.mounted) return;
    displaySnackBar(context, '下载出错：$e');
  }
}
