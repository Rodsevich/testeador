import 'dart:io';

/// {@template target_device}
/// A device or simulator that hosts the app under test.
///
/// Implementations wrap the platform-specific CLI tools (`adb` for Android
/// emulators, `xcrun simctl` for iOS simulators). Each device knows how to
/// boot itself, shut down, and produce a screenshot — the three primitives a
/// [DeviceFleet] needs to coordinate evidence capture across N targets.
/// {@endtemplate}
sealed class TargetDevice {
  /// {@macro target_device}
  const TargetDevice();

  /// Identifier used by host tools to address this device.
  ///
  /// Android: `emulator-5554`. iOS: the simulator UDID.
  String get id;

  /// `'android'` or `'ios'`.
  String get platform;

  /// Powers the device on. Idempotent: a no-op when already booted.
  Future<void> boot();

  /// Powers the device off. Idempotent.
  Future<void> shutdown();

  /// Captures the device screen into [out] (PNG) and returns the same file.
  Future<File> screenshot(File out);
}

/// {@template android_emulator}
/// An Android AVD addressable by its `emulator-<port>` serial.
///
/// Uses `adb` for screenshots and `emulator -avd <name>` / `adb emu kill` for
/// lifecycle. `adb` must be on `PATH` (or set [adbPath] explicitly).
/// {@endtemplate}
final class AndroidEmulator extends TargetDevice {
  /// {@macro android_emulator}
  const AndroidEmulator({
    required this.serial,
    this.avdName,
    this.adbPath = 'adb',
    this.emulatorPath = 'emulator',
    this.headless = false,
  });

  /// `adb` serial, e.g. `emulator-5554`.
  final String serial;

  /// Name of the AVD to boot when [boot] is called.
  ///
  /// If `null`, [boot] assumes the device is already running and only verifies
  /// it is reachable via `adb`.
  final String? avdName;

  /// Override the `adb` binary path (default: from `PATH`).
  final String adbPath;

  /// Override the `emulator` binary path (default: from `PATH`).
  final String emulatorPath;

  /// Boot with `-no-window -no-audio` for CI runs.
  final bool headless;

  @override
  String get id => serial;

  @override
  String get platform => 'android';

  @override
  Future<void> boot() async {
    if (await _isBooted()) return;
    if (avdName == null) {
      throw StateError(
        'AndroidEmulator($serial) is not booted and no avdName was provided.',
      );
    }
    await Process.start(emulatorPath, [
      '-avd', avdName!,
      '-port', _portFromSerial(serial).toString(),
      if (headless) ...['-no-window', '-no-audio', '-no-snapshot'],
    ]);
    await _waitForBootCompleted();
  }

  @override
  Future<void> shutdown() async {
    await Process.run(adbPath, ['-s', serial, 'emu', 'kill']);
  }

  @override
  Future<File> screenshot(File out) async {
    await out.parent.create(recursive: true);
    final result = await Process.run(
      adbPath,
      ['-s', serial, 'exec-out', 'screencap', '-p'],
      stdoutEncoding: null,
    );
    if (result.exitCode != 0) {
      throw ProcessException(
        adbPath,
        ['-s', serial, 'exec-out', 'screencap', '-p'],
        (result.stderr as List<int>).isEmpty
            ? 'adb screencap failed'
            : String.fromCharCodes(result.stderr as List<int>),
        result.exitCode,
      );
    }
    await out.writeAsBytes(result.stdout as List<int>);
    return out;
  }

  Future<bool> _isBooted() async {
    final r = await Process.run(adbPath, ['-s', serial, 'get-state']);
    return r.exitCode == 0 &&
        (r.stdout as String).trim() == 'device';
  }

  Future<void> _waitForBootCompleted() async {
    final deadline = DateTime.now().add(const Duration(minutes: 3));
    while (DateTime.now().isBefore(deadline)) {
      final r = await Process.run(adbPath, [
        '-s', serial, 'shell', 'getprop', 'sys.boot_completed',
      ]);
      if (r.exitCode == 0 && (r.stdout as String).trim() == '1') return;
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    throw TimeoutException(
      'AndroidEmulator($serial) failed to boot within 3 minutes.',
    );
  }

  static int _portFromSerial(String serial) {
    final m = RegExp(r'emulator-(\d+)').firstMatch(serial);
    if (m == null) {
      throw FormatException('Cannot derive port from serial: $serial');
    }
    return int.parse(m.group(1)!);
  }
}

/// {@template ios_simulator}
/// An iOS simulator addressable by its UDID.
///
/// Uses `xcrun simctl` for lifecycle and screenshots.
/// {@endtemplate}
final class IosSimulator extends TargetDevice {
  /// {@macro ios_simulator}
  const IosSimulator({required this.udid});

  /// Simulator UDID (e.g. `F7B5XXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX`).
  final String udid;

  @override
  String get id => udid;

  @override
  String get platform => 'ios';

  @override
  Future<void> boot() async {
    final r = await Process.run('xcrun', ['simctl', 'boot', udid]);
    if (r.exitCode != 0 &&
        !(r.stderr as String).contains('Booted')) {
      throw ProcessException(
        'xcrun', ['simctl', 'boot', udid], r.stderr as String, r.exitCode,
      );
    }
  }

  @override
  Future<void> shutdown() async {
    await Process.run('xcrun', ['simctl', 'shutdown', udid]);
  }

  @override
  Future<File> screenshot(File out) async {
    await out.parent.create(recursive: true);
    final r = await Process.run(
      'xcrun',
      ['simctl', 'io', udid, 'screenshot', out.path],
    );
    if (r.exitCode != 0) {
      throw ProcessException(
        'xcrun',
        ['simctl', 'io', udid, 'screenshot', out.path],
        r.stderr as String,
        r.exitCode,
      );
    }
    return out;
  }
}

/// Thrown when a device fails to reach a state within an expected window.
class TimeoutException implements Exception {
  /// Creates a [TimeoutException] with the given [message].
  const TimeoutException(this.message);

  /// Description of what timed out.
  final String message;

  @override
  String toString() => 'TimeoutException: $message';
}
