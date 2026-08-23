import 'package:rxdart/rxdart.dart';

enum FeatureFlag { paginationExample, notificationDemo }

class FeatureFlagSnapshot {
  FeatureFlagSnapshot(Map<FeatureFlag, bool> values)
    : values = Map.unmodifiable(values);
  final Map<FeatureFlag, bool> values;
  bool isEnabled(FeatureFlag flag) => values[flag] ?? false;
}

abstract interface class FeatureFlagService {
  FeatureFlagSnapshot get current;
  Stream<FeatureFlagSnapshot> get stream;
  void setOverride(FeatureFlag flag, bool value);
  void resetOverrides();
  Future<void> dispose();
}

class LocalFeatureFlagService implements FeatureFlagService {
  LocalFeatureFlagService({
    Map<FeatureFlag, bool> defaults = const {
      FeatureFlag.paginationExample: true,
      FeatureFlag.notificationDemo: true,
    },
    required this.allowOverrides,
  }) : _defaults = Map.unmodifiable(defaults),
       _subject = BehaviorSubject.seeded(
         FeatureFlagSnapshot(Map.unmodifiable(defaults)),
       );
  final bool allowOverrides;
  final Map<FeatureFlag, bool> _defaults;
  final Map<FeatureFlag, bool> _overrides = {};
  final BehaviorSubject<FeatureFlagSnapshot> _subject;
  @override
  FeatureFlagSnapshot get current => _subject.value;
  @override
  Stream<FeatureFlagSnapshot> get stream => _subject.stream.distinct();
  @override
  void setOverride(FeatureFlag flag, bool value) {
    if (!allowOverrides) return;
    _overrides[flag] = value;
    _emit();
  }

  @override
  void resetOverrides() {
    _overrides.clear();
    _emit();
  }

  void _emit() => _subject.add(
    FeatureFlagSnapshot(Map.unmodifiable({..._defaults, ..._overrides})),
  );
  @override
  Future<void> dispose() => _subject.close();
}
