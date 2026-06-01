import 'package:mcp_dart/mcp_dart.dart';
import 'package:testeador/src/mcp/device_lister.dart';
import 'package:testeador/src/mcp/tools/tools.dart';
import 'package:testeador/src/mcp/workspace.dart';
import 'package:testeador/src/multidev/device_fleet.dart';
import 'package:testeador/src/multidev/patrol_runner.dart';
import 'package:testeador/src/multidev/target_device.dart';

/// Registers `list_devices`, `boot_fleet`, `shutdown_fleet`,
/// `snapshot_fleet`, `run_patrol_fleet`.
void registerMultidevTools({
  required McpServer server,
  required WorkspaceConfig workspace,
}) {
  _registerListDevices(server);
  _registerBootFleet(server, workspace);
  _registerShutdownFleet(server, workspace);
  _registerSnapshotFleet(server, workspace);
  _registerRunPatrolFleet(server, workspace);
}

void _registerListDevices(McpServer server) {
  server.registerTool(
    'list_devices',
    description:
        'Lists locally available test devices. Combines `adb devices -l` '
        '(Android emulators + USB devices), `xcrun simctl list devices '
        '--json` (iOS simulators), and a Chrome probe (the `web` target, '
        'present when a runnable Chrome binary is found). Returns a single '
        'structured payload with serial, state, AVD name (Android emulators '
        'only), name, runtime (iOS), and chrome path/version (web). Read-only; '
        'does not boot anything.',
    inputSchema: JsonSchema.object(
      properties: {
        'platform': JsonSchema.string(
          enumValues: ['android', 'ios', 'web', 'all'],
          defaultValue: 'all',
        ),
      },
    ),
    callback: (args, extra) async {
      try {
        final platform = (args['platform'] as String?) ?? 'all';
        final listing = await listLocalDevices(platform: platform);
        return okResult(listing.toJson());
      } on Object catch (e) {
        return errResult('list_devices failed: $e');
      }
    },
  );
}

List<TargetDevice> _buildDevices(Object? raw) {
  if (raw is! List) return const [];
  final out = <TargetDevice>[];
  for (final entry in raw) {
    if (entry is! Map) continue;
    final platform = entry['platform'] as String?;
    final id = entry['id'] as String?;
    if (platform == null || id == null) continue;
    if (platform == 'android') {
      out.add(
        AndroidEmulator(
          serial: id,
          avdName: entry['avd_name'] as String?,
          headless: entry['headless'] as bool? ?? false,
        ),
      );
    } else if (platform == 'ios') {
      out.add(IosSimulator(udid: id));
    } else if (platform == 'web') {
      final viewport = _parseViewport(entry['viewport']);
      out.add(
        WebDevice(
          baseUrl: entry['url'] as String? ?? id,
          id: id,
          route: entry['route'] as String? ?? '/',
          webHeadless: entry['web_headless'] as bool? ?? true,
          width: viewport?.$1 ?? 1280,
          height: viewport?.$2 ?? 900,
        ),
      );
    }
  }
  return out;
}

/// Parses a `'<width>x<height>'` viewport string (e.g. `1280x900`).
///
/// Returns `null` when [raw] is not a well-formed `WxH` string so the caller
/// falls back to [WebDevice]'s defaults.
(int, int)? _parseViewport(Object? raw) {
  if (raw is! String) return null;
  final m = RegExp(r'^(\d+)x(\d+)$').firstMatch(raw.trim());
  if (m == null) return null;
  return (int.parse(m.group(1)!), int.parse(m.group(2)!));
}

JsonSchema _devicesSchema() => JsonSchema.array(
      items: JsonSchema.object(
        properties: {
          'platform':
              JsonSchema.string(enumValues: ['android', 'ios', 'web']),
          'id': JsonSchema.string(),
          'avd_name': JsonSchema.string(),
          'headless': JsonSchema.boolean(defaultValue: false),
          'url': JsonSchema.string(
            description: 'Web only: origin the app is served from '
                '(e.g. http://localhost:5000). Falls back to `id`.',
          ),
          'route': JsonSchema.string(
            description: 'Web only: route appended to `url` before capture.',
          ),
          'web_headless': JsonSchema.boolean(
            defaultValue: true,
            description: 'Web only: run Chromium headless during '
                '`patrol test` (--web-headless). Set false to watch locally.',
          ),
          'viewport': JsonSchema.string(
            description: 'Web only: `<width>x<height>` for `patrol test` '
                '(--web-viewport) and screenshots. Defaults to 1280x900.',
          ),
        },
        required: ['platform', 'id'],
      ),
    );

void _registerBootFleet(McpServer server, WorkspaceConfig workspace) {
  server.registerTool(
    'boot_fleet',
    description:
        'Boots every device in [devices] in parallel via '
        '`DeviceFleet.bootAll()`. Idempotent: already-booted devices are a '
        'no-op. Returns booted ids and per-device failure reasons.',
    inputSchema: JsonSchema.object(
      properties: {
        'devices': _devicesSchema(),
        'working_directory': JsonSchema.string(),
      },
      required: ['devices'],
    ),
    callback: (args, extra) async {
      try {
        final devices = _buildDevices(args['devices']);
        if (devices.isEmpty) return errResult('No devices provided.');
        final cwd = (args['working_directory'] as String?) ??
            workspace.root.path;
        final fleet = DeviceFleet(
          devices,
          evidenceDir: workspace.evidenceDir.path,
          workingDirectory: cwd,
        );
        final started = DateTime.now();
        final booted = <String>[];
        final failed = <Map<String, dynamic>>[];
        await Future.wait(
          fleet.devices.map((d) async {
            try {
              await d.boot();
              booted.add(d.id);
            } on Object catch (e) {
              failed.add({'id': d.id, 'error': '$e'});
            }
          }),
        );
        return okResult({
          'booted': booted,
          'failed': failed,
          'duration_ms':
              DateTime.now().difference(started).inMilliseconds,
        });
      } on Object catch (e) {
        return errResult('boot_fleet failed: $e');
      }
    },
  );
}

void _registerShutdownFleet(McpServer server, WorkspaceConfig workspace) {
  server.registerTool(
    'shutdown_fleet',
    description:
        'Shuts down every device in [devices] in parallel via '
        '`DeviceFleet.shutdownAll()`. Idempotent.',
    inputSchema: JsonSchema.object(
      properties: {
        'devices': _devicesSchema(),
      },
      required: ['devices'],
    ),
    callback: (args, extra) async {
      try {
        final devices = _buildDevices(args['devices']);
        if (devices.isEmpty) return errResult('No devices provided.');
        final fleet = DeviceFleet(
          devices,
          evidenceDir: workspace.evidenceDir.path,
          workingDirectory: workspace.root.path,
        );
        final started = DateTime.now();
        await fleet.shutdownAll();
        return okResult({
          'shutdown': devices.map((d) => d.id).toList(),
          'duration_ms':
              DateTime.now().difference(started).inMilliseconds,
        });
      } on Object catch (e) {
        return errResult('shutdown_fleet failed: $e');
      }
    },
  );
}

void _registerSnapshotFleet(McpServer server, WorkspaceConfig workspace) {
  server.registerTool(
    'snapshot_fleet',
    description:
        'Captures one PNG per device in parallel and (optionally) a single '
        'side-by-side composite with device labels. Writes everything under '
        '`<evidence_dir>/<label>/`, plus a `metadata.json` with capture '
        'timestamps and skew. Returns paths and wall-clock skew between the '
        'fastest and slowest shot. Use after each meaningful step in a '
        'multi-device flow to produce reviewable evidence.',
    inputSchema: JsonSchema.object(
      properties: {
        'devices': _devicesSchema(),
        'label': JsonSchema.string(),
        'composite': JsonSchema.boolean(defaultValue: true),
        'evidence_dir': JsonSchema.string(
          description: 'Defaults to `<workspace_root>/evidence`.',
        ),
        'working_directory': JsonSchema.string(),
      },
      required: ['devices', 'label'],
    ),
    callback: (args, extra) async {
      try {
        final devices = _buildDevices(args['devices']);
        if (devices.isEmpty) return errResult('No devices provided.');
        final label = args['label'] as String;
        final composite = args['composite'] as bool? ?? true;
        final evidenceDir = (args['evidence_dir'] as String?) ??
            workspace.evidenceDir.path;
        final cwd = (args['working_directory'] as String?) ??
            workspace.root.path;
        final fleet = DeviceFleet(
          devices,
          evidenceDir: evidenceDir,
          workingDirectory: cwd,
        );
        final bundle = composite
            ? await fleet.snapshotComposite(label)
            : await fleet.snapshot(label);
        return okResult({
          'label': bundle.label,
          'timestamp': bundle.timestamp,
          'skew_ms': bundle.skewMs,
          'shots': bundle.shots
              .map((s) => {
                    'platform': s.device.platform,
                    'id': s.device.id,
                    'path': s.file.path,
                    'captured_at_ms': s.capturedAtMs,
                  })
              .toList(),
          if (bundle.composite != null)
            'composite_path': bundle.composite!.path,
          'metadata_path': '$evidenceDir/$label/metadata.json',
        });
      } on Object catch (e) {
        return errResult('snapshot_fleet failed: $e');
      }
    },
  );
}

void _registerRunPatrolFleet(McpServer server, WorkspaceConfig workspace) {
  server.registerTool(
    'run_patrol_fleet',
    description:
        'Runs a Patrol integration test in parallel across multiple devices '
        'via `DeviceFleet.runPatrolAcross()`. Spawns one `patrol test` '
        'subprocess per device with a `DEVICE_ID` env var so the test can '
        'branch on which actor it represents. Returns per-device exit code, '
        'pass/fail, and stdout/stderr tails (last 4 KB each). Requires '
        '`working_directory` to point at the Flutter package that owns the '
        'integration test. Web devices (`platform: web`) run '
        '`patrol test --device chrome` with the `--web-*` flags (Patrol 4.0+ '
        'drives Flutter web via Playwright; needs Node + patrol_cli 4.x). When '
        '`execute: false`, returns the planned commands without spawning.',
    inputSchema: JsonSchema.object(
      properties: {
        'devices': _devicesSchema(),
        'target': JsonSchema.string(
          description: 'Path of the integration_test/*.dart file.',
        ),
        'env_per_device': JsonSchema.object(),
        'working_directory': JsonSchema.string(),
        'execute': JsonSchema.boolean(defaultValue: true),
      },
      required: ['devices', 'target', 'working_directory'],
    ),
    callback: (args, extra) async {
      try {
        final devices = _buildDevices(args['devices']);
        if (devices.isEmpty) return errResult('No devices provided.');
        final target = args['target'] as String;
        final cwd = args['working_directory'] as String;
        final envPerDevice = <String, Map<String, String>>{};
        final raw = args['env_per_device'];
        if (raw is Map) {
          raw.forEach((k, v) {
            if (k is String && v is Map) {
              envPerDevice[k] = {
                for (final e in v.entries)
                  if (e.key is String && e.value is String)
                    e.key as String: e.value as String,
              };
            }
          });
        }
        final commands = devices
            .map(
              (d) => {
                'device_id': d.id,
                'command': ['patrol', ...patrolCommandFor(d, target)],
                'env': {'DEVICE_ID': d.id, ...?envPerDevice[d.id]},
              },
            )
            .toList();
        final execute = args['execute'] as bool? ?? true;
        if (!execute) {
          return okResult({
            'working_directory': cwd,
            'planned': commands,
            'execute': false,
          });
        }
        final fleet = DeviceFleet(
          devices,
          evidenceDir: workspace.evidenceDir.path,
          workingDirectory: cwd,
        );
        final started = DateTime.now();
        final results = await fleet.runPatrolAcross(
          target: target,
          envPerDevice: envPerDevice,
        );
        return okResult({
          'working_directory': cwd,
          'results': results.map(_patrolResultToJson).toList(),
          'duration_ms':
              DateTime.now().difference(started).inMilliseconds,
        });
      } on Object catch (e) {
        return errResult('run_patrol_fleet failed: $e');
      }
    },
  );
}

Map<String, dynamic> _patrolResultToJson(PatrolResult r) {
  String tail(String s) {
    const max = 4096;
    if (s.length <= max) return s;
    return '…(truncated)…\n${s.substring(s.length - max)}';
  }

  return {
    'device_id': r.device.id,
    'platform': r.device.platform,
    'exit_code': r.exitCode,
    'passed': r.passed,
    'stdout_tail': tail(r.stdout),
    'stderr_tail': tail(r.stderr),
  };
}
