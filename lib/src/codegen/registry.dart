import 'dart:async';

import 'package:testeador/src/test_step.dart';

/// Async hook signature used by `setUp`/`tearDown` and the test body itself.
typedef CapturedHook = FutureOr<void> Function();

/// Snapshot of a single `test('name', body, tags: [...])` call discovered
/// during codegen and materialized at runtime through the `captured.dart` shim.
///
/// The [setUps] and [tearDowns] are the group-scoped hooks that enclose the
/// test in declaration order: setUps run outer→inner, tearDowns run
/// inner→outer.
class CapturedTest {
  /// Builds a captured snapshot. Only the codegen output constructs these;
  /// user code consumes them indirectly via `TestInjector` getters.
  CapturedTest({
    required this.packageName,
    required this.sourceUri,
    required this.groupChain,
    required this.name,
    required this.tags,
    required this.setUps,
    required this.tearDowns,
    required this.body,
  });

  /// Name of the Dart package the original `test()` lives in.
  final String packageName;

  /// Package-relative URI of the source file, e.g. `test/foo_test.dart`.
  final String sourceUri;

  /// Enclosing `group()` chain, outermost first.
  final List<String> groupChain;

  /// Literal first argument passed to `test('...')`.
  final String name;

  /// Union of the `tags:` parameter and any group-inherited tags.
  final Set<String> tags;

  /// Group-scoped `setUp` hooks, ordered outer→inner.
  final List<CapturedHook> setUps;

  /// Group-scoped `tearDown` hooks, ordered inner→outer.
  final List<CapturedHook> tearDowns;

  /// The captured `test()` body, preserving its original closure context.
  final CapturedHook body;

  /// `<package>:<group1>/<group2>/.../<name>`, with the `/` collapsed when
  /// the test is not nested in any group.
  String get fqId {
    final groups = groupChain.join('/');
    return groups.isEmpty
        ? '$packageName:$name'
        : '$packageName:$groups/$name';
  }

  /// Materializes this snapshot as a `TestStep` that runs setUps → body →
  /// tearDowns, respecting nesting order.
  TestStep toStep() {
    return TestStep(
      name: name,
      action: () async {
        for (final s in setUps) {
          await s();
        }
        try {
          await body();
        } finally {
          for (final t in tearDowns) {
            await t();
          }
        }
      },
    );
  }
}

/// In-memory index of every captured test produced by the codegen.
///
/// Consumers use [byFqId] (driven by the generated `TestInjector.<id>`
/// getters), [byName], [byTags], and [byRegExp]. Lookups are linear; the table
/// is expected to stay small (≤ a few thousand entries).
class Registry {
  /// Builds a registry from the codegen-produced list of captured tests.
  Registry(this._tests);

  final List<CapturedTest> _tests;

  late final Map<String, CapturedTest> _byFqId = {
    for (final t in _tests) t.fqId: t,
  };

  /// Looks up by fully-qualified id. Used by the generated static getters,
  /// where the id is known at compile time.
  TestStep byFqId(String fqId) {
    final t = _byFqId[fqId];
    if (t == null) {
      throw StateError(
        'testeador: no captured test with fqId "$fqId". '
        'The generated TestInjector likely points at a stale codegen output — '
        'run `dart run build_runner build` to refresh.',
      );
    }
    return t.toStep();
  }

  /// Looks up tests by partial id. Accepted forms:
  ///
  /// - `name`              → any test whose name equals `name`
  /// - `pkg:name`          → restricted to `pkg`
  /// - `pkg:g1/g2/name`    → fully qualified
  /// - `g1/.../name`       → restricted by group chain in any package
  ///
  /// Returns every match. Throws if nothing matches.
  List<TestStep> byName(String spec) {
    final colon = spec.indexOf(':');
    final String? pkg;
    final String tail;
    if (colon == -1) {
      pkg = null;
      tail = spec;
    } else {
      pkg = spec.substring(0, colon);
      tail = spec.substring(colon + 1);
    }
    final slash = tail.lastIndexOf('/');
    final List<String> groupChain;
    final String name;
    if (slash == -1) {
      groupChain = const [];
      name = tail;
    } else {
      groupChain = tail.substring(0, slash).split('/');
      name = tail.substring(slash + 1);
    }

    final matches = _tests.where((t) {
      if (pkg != null && t.packageName != pkg) return false;
      if (groupChain.isNotEmpty && !_listEquals(t.groupChain, groupChain)) {
        return false;
      }
      return t.name == name;
    }).toList();

    if (matches.isEmpty) {
      throw StateError(
        'testeador: no captured test matches "$spec". '
        'Known names sample: ${_sampleNames()}.',
      );
    }
    return matches.map((t) => t.toStep()).toList();
  }

  /// Returns every test whose [CapturedTest.tags] contains [tag].
  List<TestStep> byTags(String tag) =>
      _tests.where((t) => t.tags.contains(tag)).map((t) => t.toStep()).toList();

  /// Returns every test whose `name` matches [pattern].
  List<TestStep> byRegExp(Pattern pattern) => _tests
      .where((t) => _patternMatches(pattern, t.name))
      .map((t) => t.toStep())
      .toList();

  String _sampleNames() {
    final names = _tests.take(5).map((t) => '"${t.fqId}"').join(', ');
    if (_tests.length <= 5) return names;
    return '$names, ... (${_tests.length} total)';
  }

  static bool _patternMatches(Pattern p, String input) {
    if (p is RegExp) return p.hasMatch(input);
    if (p is String) return input.contains(p);
    return p.allMatches(input).isNotEmpty;
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
