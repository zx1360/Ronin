// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'service_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$initialInfosHash() => r'4fe40f9033b5b4f806ed604fcd918fbdbf96b1a7';

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

/// See also [initialInfos].
@ProviderFor(initialInfos)
const initialInfosProvider = InitialInfosFamily();

/// See also [initialInfos].
class InitialInfosFamily extends Family<AsyncValue<Map<String, dynamic>>> {
  /// See also [initialInfos].
  const InitialInfosFamily();

  /// See also [initialInfos].
  InitialInfosProvider call({
    required bool onlyChanged,
  }) {
    return InitialInfosProvider(
      onlyChanged: onlyChanged,
    );
  }

  @override
  InitialInfosProvider getProviderOverride(
    covariant InitialInfosProvider provider,
  ) {
    return call(
      onlyChanged: provider.onlyChanged,
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
  String? get name => r'initialInfosProvider';
}

/// See also [initialInfos].
class InitialInfosProvider
    extends AutoDisposeFutureProvider<Map<String, dynamic>> {
  /// See also [initialInfos].
  InitialInfosProvider({
    required bool onlyChanged,
  }) : this._internal(
          (ref) => initialInfos(
            ref as InitialInfosRef,
            onlyChanged: onlyChanged,
          ),
          from: initialInfosProvider,
          name: r'initialInfosProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$initialInfosHash,
          dependencies: InitialInfosFamily._dependencies,
          allTransitiveDependencies:
              InitialInfosFamily._allTransitiveDependencies,
          onlyChanged: onlyChanged,
        );

  InitialInfosProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.onlyChanged,
  }) : super.internal();

  final bool onlyChanged;

  @override
  Override overrideWith(
    FutureOr<Map<String, dynamic>> Function(InitialInfosRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: InitialInfosProvider._internal(
        (ref) => create(ref as InitialInfosRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        onlyChanged: onlyChanged,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<Map<String, dynamic>> createElement() {
    return _InitialInfosProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is InitialInfosProvider && other.onlyChanged == onlyChanged;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, onlyChanged.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin InitialInfosRef on AutoDisposeFutureProviderRef<Map<String, dynamic>> {
  /// The parameter `onlyChanged` of this provider.
  bool get onlyChanged;
}

class _InitialInfosProviderElement
    extends AutoDisposeFutureProviderElement<Map<String, dynamic>>
    with InitialInfosRef {
  _InitialInfosProviderElement(super.provider);

  @override
  bool get onlyChanged => (origin as InitialInfosProvider).onlyChanged;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
