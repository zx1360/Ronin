import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'selection_providers.g.dart';

/// 网格视图多选状态
class MediaSelectionState {
  const MediaSelectionState({
    this.active = false,
    this.ids = const {},
    this.order = const [],
  });

  /// 是否处于选择模式
  final bool active;

  /// 选中的媒体 ID
  final Set<String> ids;

  /// 选中顺序 (捆绑时第一个为主文件)
  final List<String> order;

  int get count => ids.length;

  bool contains(String id) => ids.contains(id);

  /// 选中序号 (从 1 开始), 未选中返回 null
  int? orderOf(String id) {
    final index = order.indexOf(id);
    return index >= 0 ? index + 1 : null;
  }
}

/// 网格视图多选 (随页面存活, 退出页面即重置)
@riverpod
class MediaSelection extends _$MediaSelection {
  @override
  MediaSelectionState build() => const MediaSelectionState();

  /// 长按进入选择模式并选中首个文件
  void beginWith(String id) {
    if (state.active) return;
    state = MediaSelectionState(active: true, ids: {id}, order: [id]);
  }

  /// 切换单个文件的选中状态; 全部取消时自动退出选择模式
  void toggle(String id) {
    final ids = Set<String>.from(state.ids);
    final order = List<String>.from(state.order);
    if (ids.remove(id)) {
      order.remove(id);
    } else {
      ids.add(id);
      order.add(id);
    }
    state = MediaSelectionState(active: ids.isNotEmpty, ids: ids, order: order);
  }

  /// 全选; 已全选时改为取消全选
  void toggleAll(List<String> assetIds) {
    if (state.count == assetIds.length) {
      exit();
      return;
    }
    state = MediaSelectionState(
      active: true,
      ids: assetIds.toSet(),
      order: List<String>.from(assetIds),
    );
  }

  /// 退出选择模式
  void exit() => state = const MediaSelectionState();
}
