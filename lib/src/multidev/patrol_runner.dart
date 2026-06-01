import 'dart:io';

import 'package:testeador/src/multidev/target_device.dart';

/// {@template patrol_runner}
/// Spawns a `patrol test` subprocess targeting a specific device.
///
/// Patrol's UI driving API (`tester`, `NativeAutomator`, `PlatformAutomator`)
/// lives inside the runtime of a `patrolTest` block — there is no remote
/// channel a host can use to send "tap here" RPCs. The minimum useful unit is
/// therefore a whole *agent flow* (a coherent UI scenario in a single Patrol
/// test file), invoked from the host as one subprocess per device. A
/// `DeviceFleet` composes these with `Future.wait` so several devices act in
/// parallel.
/// {@endtemplate}
abstract class PatrolRunner {
  /// Spawns `patrol test --target <target> --device <device.patrolDeviceId>`,
  /// appending any device-specific [TargetDevice.patrolExtraArgs] (e.g. the
  /// `--web-*` flags for a [WebDevice]).
  ///
  /// [env] is merged with the host environment. A `DEVICE_ID` variable is
  /// always set so the agent flow can branch on which device it is running on.
  static Future<PatrolResult> runOn(
    TargetDevice device, {
    required String target,
    Map<String, String> env = const {},
    String workingDirectory = '.',
    String patrolPath = 'patrol',
  }) async {
    final result = await Process.run(
      patrolPath,
      patrolCommandFor(device, target),
      environment: {'DEVICE_ID': device.id, ...env},
      workingDirectory: workingDirectory,
    );
    return PatrolResult(
      device: device,
      exitCode: result.exitCode,
      stdout: result.stdout as String,
      stderr: result.stderr as String,
    );
  }
}

/// Builds the argument list for `patrol test` targeting [device].
///
/// Single source of truth shared by [PatrolRunner.runOn] (which spawns it) and
/// the MCP `run_patrol_fleet` tool (which can preview it with `execute: false`)
/// so the planned command always matches the executed one — including the
/// `--web-*` flags a [WebDevice] contributes via
/// [TargetDevice.patrolExtraArgs].
///
/// ```text
/// android  → test --target <t> --device emulator-5554
/// ios      → test --target <t> --device <udid>
/// web      → test --target <t> --device chrome --web-headless true \
///                 --web-viewport 1280x900
/// ```
List<String> patrolCommandFor(TargetDevice device, String target) => [
      'test',
      '--target',
      target,
      '--device',
      device.patrolDeviceId,
      ...device.patrolExtraArgs(),
    ];

/// {@template patrol_result}
/// Outcome of one `patrol test` subprocess for one device.
/// {@endtemplate}
class PatrolResult {
  /// {@macro patrol_result}
  const PatrolResult({
    required this.device,
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  /// The device this run targeted.
  final TargetDevice device;

  /// `0` if Patrol passed, non-zero otherwise.
  final int exitCode;

  /// Patrol's stdout (test output, including any flutter logs).
  final String stdout;

  /// Patrol's stderr.
  final String stderr;

  /// `true` when `exitCode == 0`.
  bool get passed => exitCode == 0;

  @override
  String toString() => 'PatrolResult(${device.id}, exit=$exitCode, '
      'passed=$passed)';
}
