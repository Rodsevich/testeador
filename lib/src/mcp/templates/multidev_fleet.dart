// Raw strings keep template bodies safe to evolve: any future `${expr}`
// added to the snippet stays literal instead of being treated as Dart
// interpolation.
// ignore_for_file: unnecessary_raw_strings

/// Template for a multi-device flow built on `DeviceFleet` + Patrol.
///
/// Placeholders:
///   {{flow_function}}    Function name (e.g. `buildBattleJourneyFlow`).
///   {{flow_name}}        Human-readable flow name.
///   {{tags}}             Comma-separated tag literals.
///   {{android_serial_a}} First emulator serial (e.g. `emulator-5554`).
///   {{android_serial_b}} Second emulator serial (e.g. `emulator-5556`).
///   {{patrol_target}}    Path of the Patrol integration test file.
///   {{flutter_dir}}      Working directory of the Flutter package.
const multidevFleetTemplate = r'''
import 'package:testeador/testeador.dart';

/// Multi-device flow: two emulators drive a shared backend in lockstep
/// via Patrol. Each device receives its own env so the integration test
/// can branch on `DEVICE_ID`.
TestFlowLasting {{flow_function}}() {
  final fleet = DeviceFleet(
    const [
      AndroidEmulator(serial: '{{android_serial_a}}'),
      AndroidEmulator(serial: '{{android_serial_b}}'),
    ],
    workingDirectory: '{{flutter_dir}}',
  );

  return TestFlowLasting(
    name: '{{flow_name}}',
    tags: { {{tags}} },
    steps: [
      TestStep(
        name: 'Boot the fleet',
        action: fleet.bootAll,
      ),
      TestStep(
        name: 'Capture the lobby on both devices',
        action: () => fleet.snapshotComposite('01-lobby'),
      ),
      TestStep(
        name: 'Drive the journey across both devices in parallel',
        action: () => fleet.runPatrolAcross(
          target: '{{patrol_target}}',
          envPerDevice: const {
            '{{android_serial_a}}': {'ROLE': 'host'},
            '{{android_serial_b}}': {'ROLE': 'guest'},
          },
        ),
      ),
      TestStep(
        name: 'Shut the fleet down',
        action: fleet.shutdownAll,
      ),
    ],
  );
}
''';
