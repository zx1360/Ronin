import 'package:torrid/core/constants/paging.dart';
import 'package:torrid/features/gallery/models/media_asset.dart';

/// 媒体分页游标
///
/// 页大小、是否还有更多、下一页起点、去重追加都由这里给出, 画廊下载批次与
/// 相册页(immich)浏览分页共用同一套规则, 不再各写一遍。
/// [total] 未知时（如画廊批次接口不下发总数）按"整页即未到底"判断。
class MediaPager {
  MediaPager({this.pageSize = defaultPageSize});

  /// 服务端与客户端共用的页大小（唯一引用 [mediaPageSize] 的地方）
  static const int defaultPageSize = mediaPageSize;

  final int pageSize;

  final List<MediaAsset> _items = [];
  int _offset = 0;
  int? _total;
  bool _exhausted = false;

  /// 已加载的媒体（按到达顺序, 同一 id 只保留一行）
  List<MediaAsset> get items => List.unmodifiable(_items);

  /// 下一页的服务端 offset
  int get offset => _offset;

  /// 服务端总数（未知时为已消费条数）
  int get total => _total ?? _offset;

  /// 是否还有下一页
  bool get hasMore => !_exhausted && (_total == null || _offset < _total!);

  /// 追加一页结果: 按 id 去重（重复行以新数据覆盖并保持原位置）,
  /// offset 前进整页条数（服务端游标不受本地去重影响）。
  void add(List<MediaAsset> page, {int? total}) {
    final indexById = {
      for (var i = 0; i < _items.length; i++) _items[i].id: i,
    };
    for (final asset in page) {
      final index = indexById[asset.id];
      if (index == null) {
        indexById[asset.id] = _items.length;
        _items.add(asset);
      } else {
        _items[index] = asset;
      }
    }
    _offset += page.length;
    if (total != null) _total = total;
    // 空页 / 不足一页即到底; 服务端给出总数时以总数收口
    _exhausted = page.length < pageSize || (_total != null && _offset >= _total!);
  }

  /// 对齐起点（如画廊以本地已缓存条数作为游标）
  void seek(int offset) {
    _items.clear();
    _offset = offset < 0 ? 0 : offset;
    _total = null;
    _exhausted = false;
  }

  void reset() => seek(0);
}
