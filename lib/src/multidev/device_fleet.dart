import 'dart:io';

import 'package:testeador/src/multidev/patrol_runner.dart';
import 'package:testeador/src/multidev/screenshot_composer.dart';
import 'package:testeador/src/multidev/screenshot_evidence.dart';
import 'package:testeador/src/multidev/target_device.dart';

/// {@template device_fleet}
/// A set of devices (emulators and/or simulators) driven in lockstep by a
/// testeador `TestFlow`.
///
/// A fleet is the unit of orchestration:
///  - Boots every device with [bootAll].
///  - Drives UI scenarios across them by invoking Patrol per device in
///    parallel via [runPatrolAcross] / [runPatrolOn].
///  - Captures synchronized evidence via [snapshot] or [snapshotComposite].
///  - Tears them down with [shutdownAll].
/// {@endtemplate}
class DeviceFleet {
  /// {@macro device_fleet}
  DeviceFleet(
    this.devices, {
    this.evidenceDir = 'evidence',
    this.workingDirectory = '.',
  });

  /// The devices in this fleet. Order is significant: composite screenshots
  /// lay out columns in this order, and serialized metadata follows it too.
  final List<TargetDevice> devices;

  /// Root directory where evidence labels are persisted.
  final String evidenceDir;

  /// Working directory passed to Patrol subprocesses (usually the Flutter
  /// package containing the integration tests).
  final String workingDirectory;

  /// Boots every device in parallel.
  Future<void> bootAll() => Future.wait(devices.map((d) => d.boot()));

  /// Shuts down every device in parallel.
  Future<void> shutdownAll() =>
      Future.wait(devices.map((d) => d.shutdown()));

  /// Captures one PNG per device under `evidence/<label>/`.
  ///
  /// Each device runs its screenshot tool concurrently via `Future.wait`;
  /// the resulting [ScreenshotBundle.skewMs] is the wall-clock spread between
  /// the fastest and slowest shot (typically < 100 ms on M-series Macs).
  Future<ScreenshotBundle> snapshot(String label) async {
    final dir = Directory('$evidenceDir/$label')..createSync(recursive: true);
    final ts = DateTime.now().toUtc().toIso8601String();

    final shots = await Future.wait(devices.map((d) async {
      final out = File('${dir.path}/${d.platform}-${d.id}.png');
      await d.screenshot(out);
      return DeviceShot(
        device: d,
        file: out,
        capturedAtMs: DateTime.now().millisecondsSinceEpoch,
      );
    }));

    final times = shots.map((s) => s.capturedAtMs).toList()..sort();
    final skewMs = times.isEmpty ? 0 : times.last - times.first;

    final bundle = ScreenshotBundle(
      label: label,
      timestamp: ts,
      shots: shots,
      skewMs: skewMs,
    );
    await bundle.writeMetadata(dir: dir);
    return bundle;
  }

  /// Captures one PNG per device PLUS a single `composite.png` with all
  /// devices laid out horizontally with headers.
  ///
  /// This is the artifact AI agents and reviewers actually look at.
  Future<ScreenshotBundle> snapshotComposite(String label) async {
    final bundle = await snapshot(label);
    final dir = Directory('$evidenceDir/$label');
    final composite = await ScreenshotComposer.sideBySide(
      bundle.shots.map((s) => s.file).toList(),
      output: File('${dir.path}/composite.png'),
      labels: devices.map((d) => '${d.platform} · ${d.id}').toList(),
    );
    final withComposite = bundle.withComposite(composite);
    await withComposite.writeMetadata(dir: dir);
    return withComposite;
  }

  /// Spawns `patrol test --target <target> --device <id>` for **every** device
  /// IN PARALLEL.
  ///
  /// Each device receives its own env via [envPerDevice] (keyed by device id)
  /// — typically the trainer name, team, or any branching input the agent
  /// flow needs to know which actor it is representing.
  Future<List<PatrolResult>> runPatrolAcross({
    required String target,
    required Map<String, Map<String, String>> envPerDevice,
  }) {
    return Future.wait(devices.map((d) {
      final env = envPerDevice[d.id] ?? const <String, String>{};
      return PatrolRunner.runOn(
        d,
        target: target,
        env: env,
        workingDirectory: workingDirectory,
      );
    }));
  }

  /// Spawns `patrol test --target <target> --device <id>` for ONE device.
  ///
  /// Convenience for steps where only one actor needs to take a UI action and
  /// the others are passive observers waiting on a stream event.
  Future<PatrolResult> runPatrolOn({
    required TargetDevice device,
    required String target,
    Map<String, String> env = const {},
  }) =>
      PatrolRunner.runOn(
        device,
        target: target,
        env: env,
        workingDirectory: workingDirectory,
      );
}
