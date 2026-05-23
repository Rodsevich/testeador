// dart test entry point for the Serverpod streaming example.
//
// Boot two Android emulators first (`emulator-5554` and `emulator-5556`), then:
//
//     dart test test/contract_test.dart -N streaming
//
// The flow drives the Flutter app on both devices in parallel via Patrol and
// writes side-by-side composite screenshots under `evidence/` for AI agents
// and reviewers to inspect.

import 'package:testeador/testeador.dart';

import 'flows/streaming_smoke_flow.dart';

void main() {
  Testeador(
    flows: [
      buildStreamingSmokeFlow(),
    ],
  ).registerWithDartTest();
}
