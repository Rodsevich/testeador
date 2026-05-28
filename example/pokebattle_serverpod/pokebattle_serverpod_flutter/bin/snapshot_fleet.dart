// CLI helper: capture a synchronized snapshot from N booted devices and write
// `evidence/<label>/composite.png` plus per-device PNGs and metadata.json.
//
// `testeador` is a dev_dependency of this Flutter example (it must not ship in
// the production app), but this dev-only `bin/` script legitimately imports
// it. Silencing the false-positive lint:
// ignore_for_file: depend_on_referenced_packages
//
// Usage:
//
//     dart run bin/snapshot_fleet.dart <label> [device-id ...]
//
// Defaults to the two Android emulators used by the streaming smoke flow.
//
// Designed for AI agents to grab evidence at any point of a development
// session, not just inside a test run.

import 'dart:io';

import 'package:testeador/testeador.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart run bin/snapshot_fleet.dart <label> [device-id ...]',
    );
    exit(64);
  }
  final label = args.first;
  final deviceIds = args.length > 1
      ? args.sublist(1)
      : const ['emulator-5554', 'emulator-5556'];

  final fleet = DeviceFleet(
    deviceIds.map((id) => AndroidEmulator(serial: id)).toList(),
  );

  final bundle = await fleet.snapshotComposite(label);
  stdout.writeln(
    'Wrote ${bundle.shots.length} shots + composite '
    'to ${bundle.composite!.parent.path}',
  );
  stdout.writeln('Skew: ${bundle.skewMs} ms');
}
