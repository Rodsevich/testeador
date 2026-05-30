// GENERATED CODE — DO NOT MODIFY BY HAND.
// Produced by testeador codegen.
// ignore_for_file: type=lint

import 'package:testeador/codegen.dart';
import 'package:testeador/testeador.dart';
import 'package:inject_demo/src/_testeador/math_test.testeador.dart' as _f0;

// Captured from inject_demo:test/math_test.dart

Registry _buildTesteadorRegistry() {
  final all = <CapturedTest>[];
  final _f0_state = CaptureState(
    packageName: 'inject_demo',
    sourceUri: 'test/math_test.dart',
  );
  all.addAll(runCapture(_f0_state, _f0.$entry));
  return Registry(all);
}

/// Generated entry-point. See `TestInjector` static getters for per-test references.
abstract final class TestInjector {
  static final Registry _registry = _buildTesteadorRegistry();

  /// `inject_demo:add/returns sum of two positives` — tags: [pure, smoke]
  static TestStep get returnsSumOfTwoPositives =>
      _registry.byFqId('inject_demo:add/returns sum of two positives');

  /// `inject_demo:add/is commutative` — tags: [pure]
  static TestStep get isCommutative =>
      _registry.byFqId('inject_demo:add/is commutative');

  /// `inject_demo:multiply/returns product of two positives` — tags: [smoke]
  static TestStep get returnsProductOfTwoPositives =>
      _registry.byFqId('inject_demo:multiply/returns product of two positives');

  /// `inject_demo:multiply/returns zero when any factor is zero` — tags: []
  static TestStep get returnsZeroWhenAnyFactorIsZero =>
      _registry.byFqId('inject_demo:multiply/returns zero when any factor is zero');

  /// Looks up tests by partial id (see [Registry.byName]).
  static List<TestStep> byName(String spec) => _registry.byName(spec);

  /// Looks up tests whose tags contain [tag].
  static List<TestStep> byTags(String tag) => _registry.byTags(tag);

  /// Looks up tests whose name matches [pattern].
  static List<TestStep> byRegExp(Pattern pattern) => _registry.byRegExp(pattern);
}
