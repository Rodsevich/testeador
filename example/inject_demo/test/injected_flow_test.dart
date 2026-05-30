// Demonstrates how a `TestFlow` reuses existing `test()` blocks via the
// generated `TestInjector`.

import 'package:inject_demo/test_injector.g.dart';
import 'package:testeador/testeador.dart';

void main() {
  Testeador(
    flows: [
      TestFlowLasting(
        name: 'math contract',
        tags: const {'smoke'},
        steps: [
          // Static reference (compile-checked).
          TestInjector.returnsSumOfTwoPositives,
          TestInjector.returnsProductOfTwoPositives,
          // Dynamic by tag.
          ...TestInjector.byTags('pure'),
          // Dynamic by regex.
          ...TestInjector.byRegExp(RegExp('returns zero')),
        ],
      ),
    ],
  ).registerWithDartTest();
}
