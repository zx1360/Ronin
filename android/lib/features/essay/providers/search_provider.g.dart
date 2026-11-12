// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(essaySearchIndex)
final essaySearchIndexProvider = EssaySearchIndexProvider._();

final class EssaySearchIndexProvider
    extends
        $FunctionalProvider<
          AsyncValue<EssaySearchIndex>,
          EssaySearchIndex,
          FutureOr<EssaySearchIndex>
        >
    with $FutureModifier<EssaySearchIndex>, $FutureProvider<EssaySearchIndex> {
  EssaySearchIndexProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'essaySearchIndexProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$essaySearchIndexHash();

  @$internal
  @override
  $FutureProviderElement<EssaySearchIndex> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<EssaySearchIndex> create(Ref ref) {
    return essaySearchIndex(ref);
  }
}

String _$essaySearchIndexHash() => r'd0d98775a61eeea645d7796c65e2ae953a4d3b73';
