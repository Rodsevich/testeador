/// Drop-in replacement for `package:test/test.dart` used by codegen-transformed
/// `*_test.dart` files. Re-exports every symbol from `package:test/test.dart`
/// except the lifecycle hooks (`test`, `group`, `setUp`, `setUpAll`,
/// `tearDown`, `tearDownAll`), which this library overrides to capture them
/// into a [CaptureState] instead of registering them with the real test
/// runner.
///
/// The transformer rewrites `import 'package:test/test.dart';` to
/// `import 'package:testeador/src/codegen/captured.dart';` in every
/// generated copy under `.dart_tool/build/generated/<pkg>/lib/src/_testeador/`.
/// `expect`, `equals`, matchers, etc. resolve transparently through the
/// re-export.
library;

import 'package:test/test.dart' as real_test show Timeout;
import 'package:testeador/src/codegen/registry.dart';

export 'package:test/test.dart'
    hide group, setUp, setUpAll, tearDown, tearDownAll, test;

/// Re-exported [Timeout] alias for use in our interceptor signatures so they
/// match `package:test` shapes without depending on its private types.
typedef Timeout = real_test.Timeout;

class _GroupFrame {
  _GroupFrame(this.name);
  final String name;
  final List<CapturedHook> setUps = [];
  final List<CapturedHook> tearDowns = [];
  final Set<String> tags = {};
}

/// Per-file mutable buffer used by [runCapture] to collect captured tests.
///
/// The aggregator builds one [CaptureState] per `*_test.dart`, runs the
/// generated `_testeadorCapture$<hash>()` entry-point under it, and harvests
/// [captured].
class CaptureState {
  /// Builds a fresh state for the file living at [sourceUri] inside the
  /// [packageName] package.
  CaptureState({required this.packageName, required this.sourceUri});

  /// Owning package of the source file being captured.
  final String packageName;

  /// Package-relative URI of the source file, e.g. `test/foo_test.dart`.
  final String sourceUri;

  /// Tests collected so far, in declaration order.
  final List<CapturedTest> captured = [];

  final List<_GroupFrame> _stack = [];
}

CaptureState? _current;

/// Runs [entryPoint] under [state], collecting every `test(...)` call made
/// during execution into [CaptureState.captured]. Returns that list.
List<CapturedTest> runCapture(
  CaptureState state,
  void Function() entryPoint,
) {
  final previous = _current;
  _current = state;
  try {
    entryPoint();
  } finally {
    _current = previous;
  }
  return state.captured;
}

/// Capture replacement for `package:test`'s `group()`.
void group(
  Object description,
  void Function() body, {
  Object? skip,
  Object? testOn,
  Object? tags,
  Map<String, dynamic>? onPlatform,
  int? retry,
}) {
  final state = _requireState('group');
  final frame = _GroupFrame(description.toString())
    ..tags.addAll(_normalizeTags(tags));
  state._stack.add(frame);
  try {
    body();
  } finally {
    state._stack.removeLast();
  }
}

/// Capture replacement for `package:test`'s `test()`.
void test(
  Object description,
  dynamic Function() body, {
  String? testOn,
  Timeout? timeout,
  Object? skip,
  Object? tags,
  Map<String, dynamic>? onPlatform,
  int? retry,
}) {
  final state = _requireState('test');
  final groupChain = state._stack.map((f) => f.name).toList(growable: false);
  final setUps = <CapturedHook>[
    for (final f in state._stack) ...f.setUps,
  ];
  final tearDowns = <CapturedHook>[
    for (final f in state._stack.reversed) ...f.tearDowns,
  ];
  final aggregatedTags = <String>{
    for (final f in state._stack) ...f.tags,
    ..._normalizeTags(tags),
  };
  state.captured.add(
    CapturedTest(
      packageName: state.packageName,
      sourceUri: state.sourceUri,
      groupChain: groupChain,
      name: description.toString(),
      tags: aggregatedTags,
      setUps: setUps,
      tearDowns: tearDowns,
      body: () async {
        await body();
      },
    ),
  );
}

/// Capture replacement for `package:test`'s `setUp()`.
void setUp(CapturedHook callback) {
  final state = _requireState('setUp');
  _ensureFrame(state).setUps.add(callback);
}

/// Capture replacement for `package:test`'s `tearDown()`.
void tearDown(CapturedHook callback) {
  final state = _requireState('tearDown');
  _ensureFrame(state).tearDowns.add(callback);
}

/// Demoted to a per-step [setUp]. `setUpAll` semantics ("once per group") do
/// not map onto "once per injected step" — see plan §"setUpAll por group no
/// encaja con per-step".
void setUpAll(CapturedHook callback) {
  _warnDemotion('setUpAll', 'setUp');
  setUp(callback);
}

/// Demoted to a per-step [tearDown]. See [setUpAll].
void tearDownAll(CapturedHook callback) {
  _warnDemotion('tearDownAll', 'tearDown');
  tearDown(callback);
}

CaptureState _requireState(String fn) {
  final state = _current;
  if (state == null) {
    throw StateError(
      'testeador: $fn() invoked outside of runCapture — ensure the source '
      'file imports package:testeador/src/codegen/captured.dart instead of '
      'package:test/test.dart (the transformer normally does this).',
    );
  }
  return state;
}

_GroupFrame _ensureFrame(CaptureState state) {
  if (state._stack.isEmpty) {
    state._stack.add(_GroupFrame('<file>'));
  }
  return state._stack.last;
}

Set<String> _normalizeTags(Object? tags) {
  if (tags == null) return const {};
  if (tags is String) return {tags};
  if (tags is Iterable) return tags.map((e) => e.toString()).toSet();
  return const {};
}

bool _warned = false;
void _warnDemotion(String from, String to) {
  if (_warned) return;
  _warned = true;
  // Codegen warnings travel to the build_runner console; stderr is too noisy
  // here because the aggregator runs them eagerly during registry boot.
  // ignore: avoid_print
  print(
    'testeador WARN: $from demoted to $to (per-injected-step). '
    'See plan §"setUpAll por group no encaja con per-step".',
  );
}
