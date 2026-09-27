// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'style_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$styleByIdHash() => r'a666596c4a298e003b80a441fcbcdd5d110bf8d3';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// ============================================================================
/// Style 相关的 Providers
/// 提供 Style 数据的查询和派生数据
/// ============================================================================
/// 根据 styleId 获取 Style
///
/// Copied from [styleById].
@ProviderFor(styleById)
const styleByIdProvider = StyleByIdFamily();

/// ============================================================================
/// Style 相关的 Providers
/// 提供 Style 数据的查询和派生数据
/// ============================================================================
/// 根据 styleId 获取 Style
///
/// Copied from [styleById].
class StyleByIdFamily extends Family<Style?> {
  /// ============================================================================
  /// Style 相关的 Providers
  /// 提供 Style 数据的查询和派生数据
  /// ============================================================================
  /// 根据 styleId 获取 Style
  ///
  /// Copied from [styleById].
  const StyleByIdFamily();

  /// ============================================================================
  /// Style 相关的 Providers
  /// 提供 Style 数据的查询和派生数据
  /// ============================================================================
  /// 根据 styleId 获取 Style
  ///
  /// Copied from [styleById].
  StyleByIdProvider call(
    String styleId,
  ) {
    return StyleByIdProvider(
      styleId,
    );
  }

  @override
  StyleByIdProvider getProviderOverride(
    covariant StyleByIdProvider provider,
  ) {
    return call(
      provider.styleId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'styleByIdProvider';
}

/// ============================================================================
/// Style 相关的 Providers
/// 提供 Style 数据的查询和派生数据
/// ============================================================================
/// 根据 styleId 获取 Style
///
/// Copied from [styleById].
class StyleByIdProvider extends AutoDisposeProvider<Style?> {
  /// ============================================================================
  /// Style 相关的 Providers
  /// 提供 Style 数据的查询和派生数据
  /// ============================================================================
  /// 根据 styleId 获取 Style
  ///
  /// Copied from [styleById].
  StyleByIdProvider(
    String styleId,
  ) : this._internal(
          (ref) => styleById(
            ref as StyleByIdRef,
            styleId,
          ),
          from: styleByIdProvider,
          name: r'styleByIdProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$styleByIdHash,
          dependencies: StyleByIdFamily._dependencies,
          allTransitiveDependencies: StyleByIdFamily._allTransitiveDependencies,
          styleId: styleId,
        );

  StyleByIdProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.styleId,
  }) : super.internal();

  final String styleId;

  @override
  Override overrideWith(
    Style? Function(StyleByIdRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: StyleByIdProvider._internal(
        (ref) => create(ref as StyleByIdRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        styleId: styleId,
      ),
    );
  }

  @override
  AutoDisposeProviderElement<Style?> createElement() {
    return _StyleByIdProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is StyleByIdProvider && other.styleId == styleId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, styleId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin StyleByIdRef on AutoDisposeProviderRef<Style?> {
  /// The parameter `styleId` of this provider.
  String get styleId;
}

class _StyleByIdProviderElement extends AutoDisposeProviderElement<Style?>
    with StyleByIdRef {
  _StyleByIdProviderElement(super.provider);

  @override
  String get styleId => (origin as StyleByIdProvider).styleId;
}

String _$latestStyleHash() => r'fd3715f99a0730b4afb050a9e51da91d4217a4cf';

/// 获取最新的 Style（按创建时间排序）
///
/// Copied from [latestStyle].
@ProviderFor(latestStyle)
final latestStyleProvider = AutoDisposeProvider<Style?>.internal(
  latestStyle,
  name: r'latestStyleProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$latestStyleHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef LatestStyleRef = AutoDisposeProviderRef<Style?>;
String _$sortedStylesHash() => r'72338420bfd0f798c4e2d100af1c930b130407ec';

/// 获取按时间倒序排列的所有 Style
///
/// Copied from [sortedStyles].
@ProviderFor(sortedStyles)
final sortedStylesProvider = AutoDisposeProvider<List<Style>>.internal(
  sortedStyles,
  name: r'sortedStylesProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$sortedStylesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef SortedStylesRef = AutoDisposeProviderRef<List<Style>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
