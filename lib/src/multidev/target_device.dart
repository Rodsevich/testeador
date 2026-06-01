import 'dart:async';
import 'dart:io';

import 'package:testeador/src/multidev/web_capture.dart';

/// {@template target_device}
/// A device or simulator that hosts the app under test.
///
/// Implementations wrap the platform-specific CLI tools (`adb` for Android
/// emulators, `xcrun simctl` for iOS simulators, headless Chrome for the web).
/// Each device knows how to boot itself, shut down, and produce a screenshot —
/// the three primitives a `DeviceFleet` needs to coordinate evidence capture
/// across N targets.
/// {@endtemplate}
sealed class TargetDevice {
  /// {@macro target_device}
  const TargetDevice();

  /// Identifier used by host tools to address this device.
  ///
  /// Android: `emulator-5554`. iOS: the simulator UDID. Web: an evidence
  /// label (composite columns / filenames).
  String get id;

  /// `'android'`, `'ios'`, or `'web'`.
  String get platform;

  /// Selector passed to `patrol test --device <…>`.
  ///
  /// Defaults to [id] — correct for Android serials and iOS UDIDs. Web
  /// overrides this to `'chrome'` (Patrol's web target), since [id] is only an
  /// evidence label.
  String get patrolDeviceId => id;

  /// Extra flags appended to the `patrol test` command for this device.
  ///
  /// Empty for Android/iOS. Web returns its `--web-*` flags (headless,
  /// viewport) so a host-side runner reproduces the exact driven command.
  List<String> patrolExtraArgs() => const [];

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

/// {@template web_device}
/// A web app running in Chrome. Serves two roles:
///
///  1. **Driven e2e target.** [patrolDeviceId] is `'chrome'` and
///     [patrolExtraArgs] carries the `--web-*` flags, so a `DeviceFleet` can
///     run `patrol test --device chrome …` against it (Patrol 4.0+ drives
///     Flutter web via Playwright). This is the path used for e2e testing.
///  2. **Evidence surface.** [screenshot] drives headless Chrome over CDP:
///     navigate to [currentUrl], **poll [readyExpression] until the app is past
///     its splash** (default: Flutter's view attached), let it [settle], then
///     capture. Optional [cookies] / [initScript] seed an auth session or base
///     URL so a guarded route shows real content, not a login wall.
///
/// [route] is mutable so a flow can re-point the same device at the screen
/// relevant to the current step (`/`, `/players`, `/battles`, …) before each
/// snapshot.
/// {@endtemplate}
final class WebDevice extends TargetDevice {
  /// {@macro web_device}
  WebDevice({
    required this.baseUrl,
    this.id = 'chrome',
    this.route = '/',
    String? chromePath,
    this.width = 1280,
    this.height = 900,
    this.webHeadless = true,
    this.virtualTimeBudget = const Duration(seconds: 12),
    this.readyExpression = "document.querySelector('flutter-view') != null",
    this.readyTimeout = const Duration(seconds: 30),
    this.settle = const Duration(milliseconds: 1500),
    this.cookies = const {},
    this.initScript,
  }) : chromePath = chromePath ?? _resolveChrome();

  /// Origin the app is served from (e.g. `http://localhost:5000`).
  final String baseUrl;

  @override
  final String id;

  /// Route appended to [baseUrl] for the next [screenshot]. Mutable on purpose:
  /// a flow sets it to the screen that matches the current step.
  String route;

  /// Chrome/Chromium binary. Resolved per-platform when not supplied.
  final String chromePath;

  /// Viewport width passed to `--window-size`.
  final int width;

  /// Viewport height passed to `--window-size`.
  final int height;

  /// Whether `patrol test` runs Chromium headless (`--web-headless`).
  ///
  /// `true` for CI. Set `false` to watch the browser drive locally.
  final bool webHeadless;

  /// Legacy knob from the one-shot `--screenshot` path. The CDP capture in
  /// [screenshot] uses [readyTimeout] + [settle] instead; kept for source
  /// compatibility.
  final Duration virtualTimeBudget;

  /// JavaScript boolean expression polled until truthy before [screenshot]
  /// captures. The default fires once Flutter has attached its view (i.e. the
  /// first frame rendered and the HTML splash was removed). Override with a
  /// content-aware check (e.g. `document.body.innerText.includes('Welcome')`)
  /// to wait for data, not just the first paint.
  final String readyExpression;

  /// Max time to wait for [readyExpression]; capture proceeds anyway after it.
  final Duration readyTimeout;

  /// Extra pause after readiness so async content finishes painting.
  final Duration settle;

  /// Cookies injected (via CDP) before navigation — e.g. an auth session so a
  /// guarded route renders its real content instead of a login wall.
  final Map<String, String> cookies;

  /// JS evaluated on every new document before app scripts run — e.g. to seed
  /// `localStorage`/`SharedPreferences` (base URL, feature flags) at startup.
  final String? initScript;

  @override
  String get platform => 'web';

  @override
  String get patrolDeviceId => 'chrome';

  @override
  List<String> patrolExtraArgs() => [
        '--web-headless',
        '$webHeadless',
        // patrol_cli expects a JSON object here, not `WxH`.
        '--web-viewport',
        '{"width": $width, "height": $height}',
      ];

  /// Full URL captured by the next [screenshot] (`baseUrl` + `route`).
  String get currentUrl {
    final b = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final r = route.startsWith('/') ? route : '/$route';
    return '$b$r';
  }

  @override
  Future<void> boot() async {
    final r = await Process.run(chromePath, ['--version']);
    if (r.exitCode != 0) {
      throw StateError(
        'WebDevice($id): chrome binary not runnable at "$chromePath".',
      );
    }
  }

  @override
  Future<void> shutdown() async {}

  @override
  Future<File> screenshot(File out) async {
    await captureWebPage(
      chromePath: chromePath,
      url: currentUrl,
      out: out,
      width: width,
      height: height,
      readyExpression: readyExpression,
      readyTimeout: readyTimeout,
      settle: settle,
      cookies: cookies,
      initScript: initScript,
    );
    return out;
  }

  static String _resolveChrome() {
    if (Platform.isMacOS) {
      return '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
    }
    return 'google-chrome';
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
