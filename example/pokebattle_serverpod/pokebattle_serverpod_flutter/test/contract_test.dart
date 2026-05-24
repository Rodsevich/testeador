// dart test entry point for the Serverpod streaming example.
//
// Two flows:
//
//   * server-stream  — exercises the Serverpod stream contract with two
//                      Dart clients on the host. Snapshots the connected
//                      emulator after each step for visual evidence.
//                      Requires the Serverpod server running on :8080.
//                      Run with: `dart test test/contract_test.dart -N server-stream`.
//
//   * streaming      — drives the Flutter app on TWO emulators in parallel
//                      via Patrol and captures side-by-side composites.
//                      Requires `emulator-5554` + `emulator-5556` booted
//                      with the app installed, and the Serverpod server
//                      running on :8080.
//                      Run with: `dart test test/contract_test.dart -N streaming`.

import 'package:testeador/testeador.dart';

import 'flows/server_stream_flow.dart';
import 'flows/streaming_smoke_flow.dart';

void main() {
  Testeador(
    flows: [
      buildServerStreamFlow(
        devices: const [
          AndroidEmulator(serial: 'emulator-5554'),
          IosSimulator(udid: '731FF01A-89C6-49BF-A8C5-EEA637B3356E'),
        ],
      ),
      buildStreamingSmokeFlow(),
    ],
  ).registerWithDartTest();
}
