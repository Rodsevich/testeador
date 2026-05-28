/// Zone-independent assertion API for testeador flows.
///
/// `package:test`'s `expect` — and even `package:matcher`'s `expect` — call
/// `TestHandle.current`, which throws `OutsideTestException` when there is no
/// active test runner. That makes them unusable from a plain `main()`, i.e.
/// from `Testeador.run()` (the CLI / compiled-binary mode).
///
/// testeador ships its own synchronous `expect` that evaluates the matcher and
/// throws a `TestFailure` on mismatch — nothing else. The same flow then
/// asserts correctly in BOTH execution modes:
///   - `Testeador.run()` (CLI): the thrown `TestFailure` is caught by `run`
///     and reported as a failed step.
///   - `Testeador.registerWithDartTest()`: `TestFailure` is exactly what
///     `package:test` records as a failing test.
///
/// Import `package:testeador/expect.dart` and use `expect(...)` with the
/// re-exported matchers (`equals`, `isNotEmpty`, `contains`, ...). Do NOT
/// import `package:test/test.dart` for assertions in a flow, or the two
/// `expect` symbols will collide.
///
/// Only synchronous matchers are supported. For asynchronous conditions,
/// `await` the value first and assert on the result.
library;

import 'package:matcher/expect.dart' show fail;
import 'package:matcher/matcher.dart';

export 'package:matcher/expect.dart' show fail;
export 'package:matcher/matcher.dart';

/// Asserts that [actual] satisfies [matcher].
///
/// [matcher] may be a [Matcher] or a raw value (wrapped via `wrapMatcher`,
/// so `expect(x, 3)` means `expect(x, equals(3))`). Throws a `TestFailure`
/// with a formatted message on mismatch. Unlike `package:test`'s `expect`,
/// this works outside a test runner zone.
void expect(dynamic actual, dynamic matcher, {String? reason}) {
  final m = wrapMatcher(matcher);
  final matchState = <dynamic, dynamic>{};
  if (m.matches(actual, matchState)) return;

  final description = StringDescription()
    ..add('Expected: ')
    ..addDescriptionOf(m)
    ..add('\n  Actual: ')
    ..addDescriptionOf(actual);

  final mismatch = StringDescription();
  m.describeMismatch(actual, mismatch, matchState, false);
  if (mismatch.length > 0) {
    description
      ..add('\n   Which: ')
      ..add(mismatch.toString());
  }
  if (reason != null) {
    description.add('\n$reason');
  }
  fail(description.toString());
}
