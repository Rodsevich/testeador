import 'dart:convert';
import 'dart:io';

/// One Android device/emulator visible to `adb devices -l`.
class AndroidDeviceInfo {
  /// Creates an [AndroidDeviceInfo].
  const AndroidDeviceInfo({
    required this.serial,
    required this.state,
    this.avdName,
    this.product,
    this.model,
  });

  /// `adb` serial (e.g. `emulator-5554` or a USB serial).
  final String serial;

  /// `device`, `offline`, `unauthorized`, …
  final String state;

  /// AVD name (only present for emulators).
  final String? avdName;

  /// `product:` field reported by adb.
  final String? product;

  /// `model:` field reported by adb.
  final String? model;

  /// `true` when [serial] starts with `emulator-`.
  bool get isEmulator => serial.startsWith('emulator-');

  /// JSON-friendly shape.
  Map<String, dynamic> toJson() => {
        'serial': serial,
        'state': state,
        if (avdName != null) 'avd_name': avdName,
        if (product != null) 'product': product,
        if (model != null) 'model': model,
        'is_emulator': isEmulator,
      };
}

/// One iOS simulator visible to `xcrun simctl list devices --json`.
class IosSimulatorInfo {
  /// Creates an [IosSimulatorInfo].
  const IosSimulatorInfo({
    required this.udid,
    required this.name,
    required this.state,
    required this.runtime,
  });

  /// Simulator UDID.
  final String udid;

  /// Device name (e.g. `iPhone 15 Pro`).
  final String name;

  /// `Booted`, `Shutdown`, …
  final String state;

  /// Runtime identifier (e.g. `iOS 17.4`).
  final String runtime;

  /// JSON-friendly shape.
  Map<String, dynamic> toJson() => {
        'udid': udid,
        'name': name,
        'state': state,
        'runtime': runtime,
      };
}

/// The Chrome/web target, when a runnable Chrome binary is found.
///
/// Unlike Android/iOS there is no enumeration: web is a single logical target
/// (`patrol test --device chrome`). This just reports whether Chrome is
/// reachable so a caller knows web e2e is possible.
class WebTargetInfo {
  /// Creates a [WebTargetInfo].
  const WebTargetInfo({required this.chromePath, required this.version});

  /// Resolved Chrome/Chromium binary path.
  final String chromePath;

  /// `chrome --version` output (trimmed).
  final String version;

  /// Patrol device selector for the web target (always `chrome`).
  String get device => 'chrome';

  /// JSON-friendly shape.
  Map<String, dynamic> toJson() => {
        'device': device,
        'chrome_path': chromePath,
        'version': version,
      };
}

/// Combined snapshot of locally available devices.
class DeviceListing {
  /// Creates a [DeviceListing].
  const DeviceListing({
    required this.android,
    required this.ios,
    this.web,
  });

  /// Android devices/emulators.
  final List<AndroidDeviceInfo> android;

  /// iOS simulators.
  final List<IosSimulatorInfo> ios;

  /// The web target, or `null` when no runnable Chrome was found.
  final WebTargetInfo? web;

  /// JSON-friendly shape.
  Map<String, dynamic> toJson() => {
        'android': android.map((a) => a.toJson()).toList(),
        'ios': ios.map((i) => i.toJson()).toList(),
        if (web != null) 'web': web!.toJson(),
      };
}

/// Reads local devices. [platform] one of `android`, `ios`, `web`, `all`.
Future<DeviceListing> listLocalDevices({String platform = 'all'}) async {
  final android = (platform == 'all' || platform == 'android')
      ? await _adbDevices()
      : <AndroidDeviceInfo>[];
  final ios = (platform == 'all' || platform == 'ios')
      ? await _simctlDevices()
      : <IosSimulatorInfo>[];
  final web = (platform == 'all' || platform == 'web')
      ? await _webTarget()
      : null;
  return DeviceListing(android: android, ios: ios, web: web);
}

/// Probes the resolved Chrome binary via `--version`. Returns `null` when it
/// is absent or not runnable, mirroring `WebDevice`'s `_resolveChrome`.
Future<WebTargetInfo?> _webTarget() async {
  final chromePath = Platform.isMacOS
      ? '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
      : 'google-chrome';
  try {
    final r = await Process.run(chromePath, ['--version']);
    if (r.exitCode != 0) return null;
    return WebTargetInfo(
      chromePath: chromePath,
      version: (r.stdout as String).trim(),
    );
  } on Object {
    return null;
  }
}

Future<List<AndroidDeviceInfo>> _adbDevices() async {
  try {
    final r = await Process.run('adb', ['devices', '-l']);
    if (r.exitCode != 0) return const [];
    final out = <AndroidDeviceInfo>[];
    final lines = (r.stdout as String)
        .split('\n')
        .skip(1)
        .where((l) => l.trim().isNotEmpty);
    for (final line in lines) {
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length < 2) continue;
      final serial = parts[0];
      final state = parts[1];
      String? product;
      String? model;
      for (final tok in parts.skip(2)) {
        final idx = tok.indexOf(':');
        if (idx <= 0) continue;
        final k = tok.substring(0, idx);
        final v = tok.substring(idx + 1);
        if (k == 'product') product = v;
        if (k == 'model') model = v;
      }
      String? avdName;
      if (serial.startsWith('emulator-')) {
        avdName = await _adbEmulatorAvdName(serial);
      }
      out.add(AndroidDeviceInfo(
        serial: serial,
        state: state,
        avdName: avdName,
        product: product,
        model: model,
      ));
    }
    return out;
  } on ProcessException {
    return const [];
  }
}

Future<String?> _adbEmulatorAvdName(String serial) async {
  try {
    final r = await Process.run(
      'adb',
      ['-s', serial, 'emu', 'avd', 'name'],
    );
    if (r.exitCode != 0) return null;
    final first = (r.stdout as String).split('\n').first.trim();
    return first.isEmpty ? null : first;
  } on ProcessException {
    return null;
  }
}

Future<List<IosSimulatorInfo>> _simctlDevices() async {
  if (!Platform.isMacOS) return const [];
  try {
    final r = await Process.run(
      'xcrun',
      ['simctl', 'list', 'devices', '--json'],
    );
    if (r.exitCode != 0) return const [];
    final data = json.decode(r.stdout as String) as Map<String, dynamic>;
    final devices = data['devices'] as Map<String, dynamic>? ?? {};
    final out = <IosSimulatorInfo>[];
    devices.forEach((runtime, list) {
      if (list is! List) return;
      for (final d in list) {
        if (d is! Map) continue;
        out.add(IosSimulatorInfo(
          udid: d['udid'] as String? ?? '',
          name: d['name'] as String? ?? '',
          state: d['state'] as String? ?? '',
          runtime: _shortRuntime(runtime),
        ));
      }
    });
    return out;
  } on ProcessException {
    return const [];
  }
}

String _shortRuntime(String full) {
  // "com.apple.CoreSimulator.SimRuntime.iOS-17-4" → "iOS 17.4"
  final m = RegExp(r'iOS-(\d+)-(\d+)').firstMatch(full);
  if (m != null) return 'iOS ${m.group(1)}.${m.group(2)}';
  return full;
}
