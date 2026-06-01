// Host-side multidevice orchestration entry point for the streaming example.
//
// Lives under `tool/` (not `test/`) on purpose: it depends on `testeador`
// (analyzer ^13 / meta 1.18) and drives real emulators, so it must NOT be
// auto-discovered by the server's default `dart test` run (which is the
// pure-Dart codegen suite). Run it EXPLICITLY:
//
//   * server-stream — exercises the Serverpod stream contract with Dart
//                     clients on the host while the Flutter app observes.
//                     Requires the server on :8080 and the apps auto-logged in.
//                     `dart test tool/multidev/contract_test.dart -N server-stream`
//
//   * streaming     — drives the Flutter app on TWO emulators in parallel via
//                     Patrol and captures side-by-side composites. Requires
//                     `emulator-5554` + `emulator-5556` booted with the app
//                     installed, and the server on :8080.
//                     `dart test tool/multidev/contract_test.dart -N streaming`
//
// The Flutter app under test lives at `../../pokebattle_serverpod_flutter`
// (relative to the server root); the flows point Patrol there via
// `workingDirectory`.

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
