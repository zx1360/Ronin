// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'status_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(labels)
final labelsProvider = LabelsProvider._();

final class LabelsProvider
    extends $FunctionalProvider<List<Label>, List<Label>, List<Label>>
    with $Provider<List<Label>> {
  LabelsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'labelsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$labelsHash();

  @$internal
  @override
  $ProviderElement<List<Label>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<Label> create(Ref ref) {
    return labels(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<Label> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<Label>>(value),
    );
  }
}

String _$labelsHash() => r'15c6e325205f8441e645a144596ee0c93bf566a7';

@ProviderFor(idMap)
final idMapProvider = IdMapProvider._();

final class IdMapProvider
    extends
        $FunctionalProvider<
          Map<String, String>,
          Map<String, String>,
          Map<String, String>
        >
    with $Provider<Map<String, String>> {
  IdMapProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'idMapProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$idMapHash();

  @$internal
  @override
  $ProviderElement<Map<String, String>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  Map<String, String> create(Ref ref) {
    return idMap(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, String>>(value),
    );
  }
}

String _$idMapHash() => r'63a907618e96ed067625574c938707dcfe06d537';

@ProviderFor(summaries)
final summariesProvider = SummariesProvider._();

final class SummariesProvider
    extends
        $FunctionalProvider<
          List<YearSummary>,
          List<YearSummary>,
          List<YearSummary>
        >
    with $Provider<List<YearSummary>> {
  SummariesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'summariesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$summariesHash();

  @$internal
  @override
  $ProviderElement<List<YearSummary>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  List<YearSummary> create(Ref ref) {
    return summaries(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<YearSummary> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<YearSummary>>(value),
    );
  }
}

String _$summariesHash() => r'028a16a52a89ea1117a22f3b4b48cd3b0fef9910';

@ProviderFor(browseYears)
final browseYearsProvider = BrowseYearsProvider._();

final class BrowseYearsProvider
    extends $FunctionalProvider<List<String>, List<String>, List<String>>
    with $Provider<List<String>> {
  BrowseYearsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'browseYearsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$browseYearsHash();

  @$internal
  @override
  $ProviderElement<List<String>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<String> create(Ref ref) {
    return browseYears(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<String>>(value),
    );
  }
}

String _$browseYearsHash() => r'bf6f49c01694e9b5e5490ff1e9a53d992abc577a';

@ProviderFor(filteredEssays)
final filteredEssaysProvider = FilteredEssaysProvider._();

final class FilteredEssaysProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Essay>>,
          List<Essay>,
          FutureOr<List<Essay>>
        >
    with $FutureModifier<List<Essay>>, $FutureProvider<List<Essay>> {
  FilteredEssaysProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'filteredEssaysProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$filteredEssaysHash();

  @$internal
  @override
  $FutureProviderElement<List<Essay>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Essay>> create(Ref ref) {
    return filteredEssays(ref);
  }
}

String _$filteredEssaysHash() => r'b856918ad2b77208e2035f772628cf21773e34fc';

@ProviderFor(yearEssays)
final yearEssaysProvider = YearEssaysFamily._();

final class YearEssaysProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Essay>>,
          List<Essay>,
          FutureOr<List<Essay>>
        >
    with $FutureModifier<List<Essay>>, $FutureProvider<List<Essay>> {
  YearEssaysProvider._({
    required YearEssaysFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'yearEssaysProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$yearEssaysHash();

  @override
  String toString() {
    return r'yearEssaysProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<Essay>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Essay>> create(Ref ref) {
    final argument = this.argument as String;
    return yearEssays(ref, year: argument);
  }

  @override
  bool operator ==(Object other) {
    return other is YearEssaysProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$yearEssaysHash() => r'0eac36a8eb8998d5488dce7a2a66944ffda0c0dc';

final class YearEssaysFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<Essay>>, String> {
  YearEssaysFamily._()
    : super(
        retry: null,
        name: r'yearEssaysProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  YearEssaysProvider call({required String year}) =>
      YearEssaysProvider._(argument: year, from: this);

  @override
  String toString() => r'yearEssaysProvider';
}
