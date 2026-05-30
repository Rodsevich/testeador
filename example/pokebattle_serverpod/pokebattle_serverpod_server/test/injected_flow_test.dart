// dart test entrypoint that exercises the testeador codegen pipeline by
// running the InMemoryStore tests as steps of a TestFlow whose steps are
// sourced from the generated `TestInjector`.
//
// Capture source: `test/in_memory_store_test.dart` (vanilla `test()` calls).
// Generator: `dart run build_runner build` produces
// `lib/test_injector.g.dart`. Re-run codegen after editing the source tests.
//
// Run with: `dart test test/injected_flow_test.dart`.

import 'package:pokebattle_serverpod_server/test_injector.g.dart';
import 'package:testeador/testeador.dart';

void main() {
  Testeador(
    flows: [
      TestFlowLasting(
        name: 'InMemoryStore — injected via codegen',
        tags: const {'codegen', 'injected', 'in-memory-store'},
        steps: [
          TestInjector.roundTripsARegisteredUser,
          TestInjector.returnsNullForAnUnknownEmail,
          TestInjector.listsPlayersInInsertionOrder,
          TestInjector.persistsAndRetrievesABattle,
        ],
      ),
    ],
  ).registerWithDartTest();
}
