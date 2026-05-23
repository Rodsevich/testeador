import 'dart:convert';
import 'dart:io';

import 'package:testeador/src/multidev/target_device.dart';

/// {@template screenshot_bundle}
/// Result of a multi-device screenshot capture.
///
/// Contains one PNG per device, optionally a composite side-by-side image, and
/// timing metadata that callers persist as `metadata.json` next to the PNGs.
/// {@endtemplate}
class ScreenshotBundle {
  /// {@macro screenshot_bundle}
  const ScreenshotBundle({
    required this.label,
    required this.timestamp,
    required this.shots,
    required this.skewMs,
    this.composite,
  });

  /// Step label this capture belongs to (e.g. `'01-both-in-lobby'`).
  final String label;

  /// ISO-8601 UTC timestamp of the moment captures were dispatched.
  final String timestamp;

  /// One [DeviceShot] per device, in the order of the source [DeviceFleet].
  final List<DeviceShot> shots;

  /// Max wall-clock difference, in ms, between the fastest and slowest shot.
  final int skewMs;

  /// Composite PNG with all devices laid out side-by-side. `null` if
  /// [DeviceFleet.snapshot] was called instead of `snapshotComposite`.
  final File? composite;

  /// Returns a copy of this bundle with [composite] populated.
  ScreenshotBundle withComposite(File composite) => ScreenshotBundle(
        label: label,
        timestamp: timestamp,
        shots: shots,
        skewMs: skewMs,
        composite: composite,
      );

  /// Persists `metadata.json` next to the captured PNGs.
  ///
  /// The metadata is the canonical machine-readable record AI agents read to
  /// reason about the capture without parsing filenames.
  Future<File> writeMetadata({required Directory dir}) async {
    final file = File('${dir.path}/metadata.json');
    final body = {
      'label': label,
      'timestamp': timestamp,
      'skewMs': skewMs,
      'composite': composite?.path,
      'shots': shots
          .map((s) => {
                'platform': s.device.platform,
                'id': s.device.id,
                'path': s.file.path,
                'capturedAtMs': s.capturedAtMs,
              })
          .toList(),
    };
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(body));
    return file;
  }
}

/// {@template device_shot}
/// A single PNG captured from one device.
/// {@endtemplate}
class DeviceShot {
  /// {@macro device_shot}
  const DeviceShot({
    required this.device,
    required this.file,
    required this.capturedAtMs,
  });

  /// The device this shot was taken from.
  final TargetDevice device;

  /// The PNG file on disk.
  final File file;

  /// Wall-clock milliseconds since epoch when the capture completed.
  final int capturedAtMs;
}
