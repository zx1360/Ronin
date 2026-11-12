// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'style_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 根据 styleId 获取 Style

@ProviderFor(styleById)
final styleByIdProvider = StyleByIdFamily._();

/// 根据 styleId 获取 Style

final class StyleByIdProvider
    extends $FunctionalProvider<Style?, Style?, Style?>
    with $Provider<Style?> {
  /// 根据 styleId 获取 Style
  StyleByIdProvider._({
    required StyleByIdFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'styleByIdProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$styleByIdHash();

  @override
  String toString() {
    return r'styleByIdProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<Style?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Style? create(Ref ref) {
    final argument = this.argument as String;
    return styleById(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Style? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Style?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is StyleByIdProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$styleByIdHash() => r'd4acf5511f14169eedb88536f6fecdb092f3e259';

/// 根据 styleId 获取 Style

final class StyleByIdFamily extends $Family
    with $FunctionalFamilyOverride<Style?, String> {
  StyleByIdFamily._()
    : super(
        retry: null,
        name: r'styleByIdProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 根据 styleId 获取 Style

  StyleByIdProvider call(String styleId) =>
      StyleByIdProvider._(argument: styleId, from: this);

  @override
  String toString() => r'styleByIdProvider';
}

/// 获取最新的 Style（按创建时间排序）

@ProviderFor(latestStyle)
final latestStyleProvider = LatestStyleProvider._();

/// 获取最新的 Style（按创建时间排序）

final class LatestStyleProvider
    extends $FunctionalProvider<Style?, Style?, Style?>
    with $Provider<Style?> {
  /// 获取最新的 Style（按创建时间排序）
  LatestStyleProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'latestStyleProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$latestStyleHash();

  @$internal
  @override
  $ProviderElement<Style?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Style? create(Ref ref) {
    return latestStyle(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Style? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Style?>(value),
    );
  }
}

String _$latestStyleHash() => r'30514ec2d0c0207705068338effb96879fbd0d23';

/// 获取按时间倒序排列的所有 Style

@ProviderFor(sortedStyles)
final sortedStylesProvider = SortedStylesProvider._();

/// 获取按时间倒序排列的所有 Style

final class SortedStylesProvider
    extends $FunctionalProvider<List<Style>, List<Style>, List<Style>>
    with $Provider<List<Style>> {
  /// 获取按时间倒序排列的所有 Style
  SortedStylesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sortedStylesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sortedStylesHash();

  @$internal
  @override
  $ProviderElement<List<Style>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<Style> create(Ref ref) {
    return sortedStyles(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<Style> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<Style>>(value),
    );
  }
}

String _$sortedStylesHash() => r'18ed12ab178154f3bcbd66b7671763da3b3a52d7';
