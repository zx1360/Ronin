// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'service_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$initialInfosHash() => r'8aa554b3136fe1bfe513aa9a8782a018886426ef';

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
    required bool onlyNew,
  }) {
    return InitialInfosProvider(
      onlyNew: onlyNew,
    );
  }

  @override
  InitialInfosProvider getProviderOverride(
    covariant InitialInfosProvider provider,
  ) {
    return call(
      onlyNew: provider.onlyNew,
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
    required bool onlyNew,
  }) : this._internal(
          (ref) => initialInfos(
            ref as InitialInfosRef,
            onlyNew: onlyNew,
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
          onlyNew: onlyNew,
        );

  InitialInfosProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.onlyNew,
  }) : super.internal();

  final bool onlyNew;

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
        onlyNew: onlyNew,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<Map<String, dynamic>> createElement() {
    return _InitialInfosProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is InitialInfosProvider && other.onlyNew == onlyNew;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, onlyNew.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin InitialInfosRef on AutoDisposeFutureProviderRef<Map<String, dynamic>> {
  /// The parameter `onlyNew` of this provider.
  bool get onlyNew;
}

class _InitialInfosProviderElement
    extends AutoDisposeFutureProviderElement<Map<String, dynamic>>
    with InitialInfosRef {
  _InitialInfosProviderElement(super.provider);

  @override
  bool get onlyNew => (origin as InitialInfosProvider).onlyNew;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
