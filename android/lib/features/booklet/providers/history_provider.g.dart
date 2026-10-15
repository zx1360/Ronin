// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'history_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$bookletHistoryHash() => r'363344a420b4f0c200a010f0e1f34acefe1587a9';

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

/// See also [bookletHistory].
@ProviderFor(bookletHistory)
const bookletHistoryProvider = BookletHistoryFamily();

/// See also [bookletHistory].
class BookletHistoryFamily
    extends Family<AsyncValue<List<BookletHistoryEntry>>> {
  /// See also [bookletHistory].
  const BookletHistoryFamily();

  /// See also [bookletHistory].
  BookletHistoryProvider call({
    String? styleId,
    bool onlyMessages = true,
  }) {
    return BookletHistoryProvider(
      styleId: styleId,
      onlyMessages: onlyMessages,
    );
  }

  @override
  BookletHistoryProvider getProviderOverride(
    covariant BookletHistoryProvider provider,
  ) {
    return call(
      styleId: provider.styleId,
      onlyMessages: provider.onlyMessages,
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
  String? get name => r'bookletHistoryProvider';
}

/// See also [bookletHistory].
class BookletHistoryProvider
    extends AutoDisposeFutureProvider<List<BookletHistoryEntry>> {
  /// See also [bookletHistory].
  BookletHistoryProvider({
    String? styleId,
    bool onlyMessages = true,
  }) : this._internal(
          (ref) => bookletHistory(
            ref as BookletHistoryRef,
            styleId: styleId,
            onlyMessages: onlyMessages,
          ),
          from: bookletHistoryProvider,
          name: r'bookletHistoryProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$bookletHistoryHash,
          dependencies: BookletHistoryFamily._dependencies,
          allTransitiveDependencies:
              BookletHistoryFamily._allTransitiveDependencies,
          styleId: styleId,
          onlyMessages: onlyMessages,
        );

  BookletHistoryProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.styleId,
    required this.onlyMessages,
  }) : super.internal();

  final String? styleId;
  final bool onlyMessages;

  @override
  Override overrideWith(
    FutureOr<List<BookletHistoryEntry>> Function(BookletHistoryRef provider)
        create,
  ) {
    return ProviderOverride(
      origin: this,
      override: BookletHistoryProvider._internal(
        (ref) => create(ref as BookletHistoryRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        styleId: styleId,
        onlyMessages: onlyMessages,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<BookletHistoryEntry>> createElement() {
    return _BookletHistoryProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is BookletHistoryProvider &&
        other.styleId == styleId &&
        other.onlyMessages == onlyMessages;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, styleId.hashCode);
    hash = _SystemHash.combine(hash, onlyMessages.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin BookletHistoryRef
    on AutoDisposeFutureProviderRef<List<BookletHistoryEntry>> {
  /// The parameter `styleId` of this provider.
  String? get styleId;

  /// The parameter `onlyMessages` of this provider.
  bool get onlyMessages;
}

class _BookletHistoryProviderElement
    extends AutoDisposeFutureProviderElement<List<BookletHistoryEntry>>
    with BookletHistoryRef {
  _BookletHistoryProviderElement(super.provider);

  @override
  String? get styleId => (origin as BookletHistoryProvider).styleId;
  @override
  bool get onlyMessages => (origin as BookletHistoryProvider).onlyMessages;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
